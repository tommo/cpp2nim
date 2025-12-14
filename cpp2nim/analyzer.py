"""
Dependency analysis for cpp2nim.

This module analyzes dependencies between parsed headers and determines
which types should be moved to shared type files.
"""

import os
from dataclasses import dataclass, field
from typing import Any

from .config import Config, get_global_option
from .models import ParseResult, ParsedHeader
from .utils import flatten_namespace


@dataclass
class AnalysisResult:
    """Result of dependency analysis.
    
    Attributes:
        file_relationships: For each file, maps other files to the types they provide.
        shared_types: Types that should be in the shared types file.
        type_renames: Mapping of types that need renaming to avoid conflicts.
        import_graph: For each file, the files it needs to import.
    """
    file_relationships: dict[str, dict[str, set[str]]] = field(default_factory=dict)
    shared_types: set[str] = field(default_factory=set)
    type_renames: dict[str, str] = field(default_factory=dict)
    import_graph: dict[str, set[str]] = field(default_factory=dict)


class DependencyAnalyzer:
    """Analyze dependencies between parsed headers.
    
    This class determines which types are shared between files and need
    to be moved to a common types file.
    
    Example:
        >>> analyzer = DependencyAnalyzer(config)
        >>> result = analyzer.analyze(parse_result)
        >>> print(result.shared_types)
    """
    
    def __init__(self, config: Config | None = None):
        """Initialize the analyzer.
        
        Args:
            config: Configuration settings.
        """
        self.config = config or Config()
    
    def analyze(self, parse_result: ParseResult) -> AnalysisResult:
        """Perform full dependency analysis.
        
        Args:
            parse_result: The result from parsing headers.
            
        Returns:
            AnalysisResult with dependency information.
        """
        result = AnalysisResult()
        
        # Compute file relationships
        result.file_relationships = self._compute_relationships(parse_result)
        
        # Identify shared types
        result.shared_types = self._compute_shared_types(parse_result, result.file_relationships)
        
        # Compute type renames
        result.type_renames = self._compute_renames(parse_result, result.shared_types)
        
        # Build import graph
        result.import_graph = self._compute_imports(parse_result, result.file_relationships)
        
        return result
    
    def _compute_relationships(self, parse_result: ParseResult) -> dict[str, dict[str, set[str]]]:
        """Compute which files provide which types to which other files."""
        relationships: dict[str, dict[str, set[str]]] = {}
        filenames = set(parse_result.headers.keys())
        
        for filename in filenames:
            missing = parse_result.all_missing.get(filename, set())
            file_deps: dict[str, set[str]] = {}
            
            for other_file in filenames:
                if other_file == filename:
                    continue
                
                provides = parse_result.all_provides.get(other_file, set())
                
                # Direct matches
                found = missing.intersection(provides)
                
                # Enum value matches (provides may contain (value, enum) tuples)
                enum_values = [k[0] for k in provides if isinstance(k, tuple)]
                found2 = missing.intersection(enum_values)
                
                enum_found = []
                if found2:
                    for item in found2:
                        for k in provides:
                            if isinstance(k, tuple) and item == k[0]:
                                enum_found.append(k[1])
                enum_found = list(set(enum_found))
                
                if found or enum_found:
                    file_deps[other_file] = set(list(found) + enum_found)
            
            relationships[filename] = file_deps
        
        return relationships
    
    def _compute_shared_types(
        self, 
        parse_result: ParseResult,
        relationships: dict[str, dict[str, set[str]]]
    ) -> set[str]:
        """Determine which types should be in the shared types file."""
        shared: set[str] = set()
        
        # Types needed by multiple files
        for _, deps in relationships.items():
            for _, types in deps.items():
                shared.update(types)
        
        # Add dependencies of shared types
        all_shared = set(shared)
        for type_name in shared:
            deps = self._find_type_dependencies(type_name, parse_result)
            all_shared.update(deps)
        
        # Add forced shared types from config
        all_shared.update(self.config.force_shared_types)
        
        return all_shared
    
    def _find_type_dependencies(
        self, 
        type_name: str, 
        parse_result: ParseResult,
        visited: set[str] | None = None
    ) -> set[str]:
        """Find all types that a given type depends on.
        
        Args:
            type_name: The type to find dependencies for.
            parse_result: Parsed header data.
            visited: Already visited types (for cycle detection).
            
        Returns:
            Set of dependent type names.
        """
        if visited is None:
            visited = set()
        
        if type_name in visited:
            return set()
        visited.add(type_name)
        
        deps: set[str] = set()
        
        # Collect all types from all headers
        all_classes = []
        all_enums = []
        
        for header in parse_result.headers.values():
            for struct in header.structs:
                all_classes.append((struct.fully_qualified, struct.underlying_deps))
            for cls in header.classes:
                all_classes.append((cls.fully_qualified, []))
            for typedef in header.typedefs:
                all_classes.append((typedef.fully_qualified, typedef.underlying_deps))
            for enum in header.enums:
                all_enums.append(enum.fully_qualified)
        
        classes_fully = [c[0] for c in all_classes]
        
        # Find the type and its dependencies
        for fully_qualified, underlying_deps in all_classes:
            if fully_qualified != type_name:
                continue
            
            for dep in underlying_deps:
                if dep in all_enums:
                    deps.add(dep)
                elif dep in classes_fully:
                    if dep not in deps:
                        new_deps = self._find_type_dependencies(dep, parse_result, visited)
                        deps.add(dep)
                        deps.update(new_deps)
        
        return deps
    
    def _compute_renames(
        self, 
        parse_result: ParseResult,
        shared_types: set[str]
    ) -> dict[str, str]:
        """Generate new names for types that would otherwise conflict."""
        renames: dict[str, str] = {}
        
        # Find types in shared that have the same short name
        short_names: dict[str, list[str]] = {}
        
        for type_name in shared_types:
            short = type_name.split("::")[-1]
            if short not in short_names:
                short_names[short] = []
            short_names[short].append(type_name)
        
        # Rename types with conflicting short names
        root_namespace = get_global_option("root_namespace")
        
        for short, full_names in short_names.items():
            if len(full_names) > 1:
                for full in full_names:
                    new_name = self._get_new_name(full, list(renames.values()), root_namespace)
                    renames[full] = new_name
        
        return renames
    
    def _get_new_name(
        self, 
        full_name: str, 
        existing_names: list[str],
        root_namespace: str | None
    ) -> str:
        """Generate a new unique name for a type.
        
        Args:
            full_name: Fully qualified C++ name.
            existing_names: Names already in use.
            root_namespace: Root namespace to strip.
            
        Returns:
            New unique name.
        """
        parts = full_name.split("::")
        if root_namespace and parts and parts[0] == root_namespace:
            return '_'.join(parts[1:])
        return flatten_namespace(full_name)
    
    def _compute_imports(
        self, 
        parse_result: ParseResult,
        relationships: dict[str, dict[str, set[str]]]
    ) -> dict[str, set[str]]:
        """Build the import graph for generated files."""
        imports: dict[str, set[str]] = {}
        
        for filename, deps in relationships.items():
            file_imports: set[str] = set()
            for dep_file in deps.keys():
                # Convert path to module name
                basename = os.path.basename(dep_file)
                module_name = os.path.splitext(basename)[0]
                file_imports.add(module_name)
            imports[filename] = file_imports
        
        return imports


def _relationships(
    data: list[tuple[Any, ...]],
    provides: dict[str, set[str]],
    missing: dict[str, set[str]]
) -> dict[str, dict[str, set[str]]]:
    """Compute file relationships (legacy format).
    
    Args:
        data: Legacy data format from parsing.
        provides: Types provided by each file.
        missing: Missing dependencies for each file.
        
    Returns:
        Relationship mapping.
    """
    relationships: dict[str, dict[str, set[str]]] = {}
    filenames = set(item[0] for item in data)
    
    for filename in filenames:
        file_missing = missing.get(filename, set())
        file_deps: dict[str, set[str]] = {}
        
        for other in filenames:
            if other == filename:
                continue
            
            file_provides = provides.get(other, set())
            found = file_missing.intersection(file_provides)
            
            # Handle enum tuples
            enum_values = [k[0] for k in file_provides if isinstance(k, tuple)]
            found2 = file_missing.intersection(enum_values)
            
            enum_found = []
            if found2:
                for item in found2:
                    for k in file_provides:
                        if isinstance(k, tuple) and item == k[0]:
                            enum_found.append(k[1])
            enum_found = list(set(enum_found))
            
            if found or enum_found:
                file_deps[other] = set(list(found) + enum_found)
        
        relationships[filename] = file_deps
    
    return relationships


def find_dependencies(
    obj: str,
    data: list[tuple[Any, ...]],
    refobj: str | None = None,
    rec: set[str] | None = None
) -> set[str]:
    """Find all dependencies of a type (legacy format).
    
    Args:
        obj: Type name to find dependencies for.
        data: Legacy parsed data.
        refobj: Reference object (unused).
        rec: Recursion tracking set.
        
    Returns:
        Set of dependency type names.
    """
    if rec is None:
        rec = set()
    
    if obj in rec:
        return set()
    rec.add(obj)
    
    deps: set[str] = set()
    
    # Find class/typedef/struct indices
    idx_class = [j for j in range(len(data)) if len(data[j]) > 2 and data[j][2] in ["class", "typedef", "struct"]]
    classes_fully = [data[j][4]["fully_qualified"] if len(data[j]) > 4 else "" for j in idx_class]
    classes = [data[j][3] if len(data[j]) > 3 else "" for j in idx_class]
    
    # Find enum indices
    idx_enum = [j for j in range(len(data)) if len(data[j]) > 2 and data[j][2] == "enum"]
    enums_fully = [data[j][3] if len(data[j]) > 3 else "" for j in idx_enum]
    enums = ["enum " + (data[j][4]["name"] if len(data[j]) > 4 else "") for j in idx_enum]
    
    for i in range(len(data)):
        if len(data[i]) < 3:
            continue
        if data[i][2] not in ["typedef", "class", "struct"]:
            continue
        if len(data[i]) < 5:
            continue
        
        values = data[i][4]
        if values.get("fully_qualified") != obj:
            continue
        
        # Check underlying dependencies
        if "underlying_deps" in values:
            for dep in values["underlying_deps"]:
                if dep in enums_fully:
                    deps.add(dep)
                elif dep in enums:
                    k = enums.index(dep)
                    k = idx_enum[k]
                    full_name = data[k][3] if len(data[k]) > 3 else ""
                    deps.add(full_name)
                elif dep in classes_fully:
                    if dep not in deps:
                        new_deps = find_dependencies(dep, data, obj, rec)
                        deps.add(dep)
                        deps.update(new_deps)
                elif dep in classes:
                    k = classes.index(dep)
                    k = idx_class[k]
                    full_name = data[k][4]["fully_qualified"] if len(data[k]) > 4 else ""
                    if full_name not in deps:
                        new_deps = find_dependencies(full_name, data, obj, rec)
                        deps.add(full_name)
                        deps.update(new_deps)
        
        # Check template params
        if "template_params" in values and values["template_params"]:
            for param in values["template_params"]:
                if isinstance(param, tuple):
                    for k in range(len(enums_fully)):
                        enum_type = enums_fully[k]
                        if enum_type.endswith(param[1]) and "::" in param[1]:
                            if enum_type not in deps:
                                new_deps = find_dependencies(enum_type, data, obj, rec)
                                deps.add(enum_type)
                                deps.update(new_deps)
    
    return deps


def move_to_shared_types(
    new_filename: str,
    data: list[tuple[Any, ...]],
    root: str,
    relations: dict[str, dict[str, set[str]]] | None = None,
    force_shared: list[str] | None = None
) -> list[tuple[Any, ...]]:
    """Move shared types to a common file (legacy format).
    
    Args:
        new_filename: The shared types filename.
        data: Legacy parsed data (modified in place).
        root: Root directory path.
        relations: File relationships.
        force_shared: Types to force into shared file.
        
    Returns:
        Modified data with import statements added.
    """
    relations = relations or {}
    force_shared = force_shared or []
    
    # Collect objects that need to be moved
    objects: set[str] = set()
    for _, deps in relations.items():
        for _, type_set in deps.items():
            objects.update(type_set)
    
    # Add dependencies
    all_objects = set(objects)
    for obj in objects:
        deps = find_dependencies(obj, data, new_filename)
        all_objects.update(deps)
    
    all_objects.update(force_shared)
    
    # Move items to new file
    new_imports: set[str] = set()
    for obj in all_objects:
        for i in range(len(data)):
            if len(data[i]) < 3:
                continue
            
            item_type = data[i][2] if len(data[i]) > 2 else None
            
            if item_type == "const" and len(data[i]) > 3:
                values = data[i][3]
                for item in values.get("items", []):
                    if item.get("name") == obj:
                        new_imports.add(data[i][0])
                        data[i] = (new_filename,) + data[i][1:]
            
            elif item_type == "enum" and len(data[i]) > 3:
                name = data[i][3]
                if name == obj:
                    new_imports.add(data[i][0])
                    data[i] = (new_filename,) + data[i][1:]
            
            elif item_type in ["typedef", "class", "struct"] and len(data[i]) > 4:
                values = data[i][4]
                if values.get("fully_qualified") == obj:
                    new_imports.add(data[i][0])
                    data[i] = (new_filename,) + data[i][1:]
    
    # Add import statements
    new_data = []
    for imp in new_imports:
        new_data.append((imp, None, "import", [new_filename]))
    
    return new_data + data
