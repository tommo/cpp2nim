"""
Configuration for cpp2nim.

Centralized configuration using dataclasses to replace scattered function parameters
and global variables.
"""

from dataclasses import dataclass, field
from typing import Any
import os


@dataclass
class Config:
    """Configuration for cpp2nim parsing and generation.
    
    This consolidates all configuration options that were previously scattered
    across function parameters and global variables.
    
    Example:
        >>> config = Config(
        ...     search_paths=["/usr/include"],
        ...     extra_args=["-std=c++17"],
        ...     output_dir="bindings"
        ... )
    
    Attributes:
        search_paths: Include directories for clang (-I paths).
        extra_args: Additional clang compiler arguments.
        c_mode: Parse as C instead of C++ (use -x c vs -x c++).
        enum_to_const: Enum names to treat as constants instead of enums.
        ignore_files: Files to skip during parsing.
        
        output_dir: Directory for generated output.
        root_namespace: Root namespace to strip from names.
        camel_case: Convert identifiers to camelCase.
        
        type_renames: Manual type rename mappings.
        ignore_types: Types to skip during generation.
        ignore_fields: Fields to exclude from structs/classes.
        inheritable_types: Types that should be marked as inheritable.
        varargs_functions: Functions to mark as varargs.
        force_shared_types: Types to force into the shared types file.
        
        parallel: Enable parallel parsing with multiprocessing.
        num_workers: Number of worker processes (None = cpu_count).
    """
    # Parsing options
    search_paths: list[str] = field(default_factory=list)
    extra_args: list[str] = field(default_factory=list)
    c_mode: bool = False
    enum_to_const: list[str] = field(default_factory=list)
    ignore_files: list[str] = field(default_factory=list)
    
    # Output options
    output_dir: str = "."
    root_namespace: str | None = None
    camel_case: bool = True
    
    # Type handling
    type_renames: dict[str, str] = field(default_factory=dict)
    ignore_types: list[str] = field(default_factory=list)
    ignore_fields: list[str] = field(default_factory=list)
    inheritable_types: list[str] = field(default_factory=list)
    varargs_functions: list[str] = field(default_factory=list)
    force_shared_types: list[str] = field(default_factory=list)
    
    # Performance
    parallel: bool = True
    num_workers: int | None = None
    
    def to_dict(self) -> dict[str, Any]:
        """Serialize to dictionary for IPC (multiprocessing).
        
        Returns:
            Dictionary representation that can be passed between processes.
        """
        return {
            "search_paths": self.search_paths,
            "extra_args": self.extra_args,
            "c_mode": self.c_mode,
            "enum_to_const": self.enum_to_const,
            "ignore_files": self.ignore_files,
            "output_dir": self.output_dir,
            "root_namespace": self.root_namespace,
            "camel_case": self.camel_case,
            "type_renames": self.type_renames,
            "ignore_types": self.ignore_types,
            "ignore_fields": self.ignore_fields,
            "inheritable_types": self.inheritable_types,
            "varargs_functions": self.varargs_functions,
            "force_shared_types": self.force_shared_types,
            "parallel": self.parallel,
            "num_workers": self.num_workers,
        }
    
    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Config":
        """Create from dictionary (for IPC deserialization).
        
        Args:
            data: Dictionary from to_dict().
            
        Returns:
            Reconstructed Config instance.
        """
        return cls(
            search_paths=data.get("search_paths", []),
            extra_args=data.get("extra_args", []),
            c_mode=data.get("c_mode", False),
            enum_to_const=data.get("enum_to_const", []),
            ignore_files=data.get("ignore_files", []),
            output_dir=data.get("output_dir", "."),
            root_namespace=data.get("root_namespace"),
            camel_case=data.get("camel_case", True),
            type_renames=data.get("type_renames", {}),
            ignore_types=data.get("ignore_types", []),
            ignore_fields=data.get("ignore_fields", []),
            inheritable_types=data.get("inheritable_types", []),
            varargs_functions=data.get("varargs_functions", []),
            force_shared_types=data.get("force_shared_types", []),
            parallel=data.get("parallel", True),
            num_workers=data.get("num_workers"),
        )
    
    @classmethod
    def from_yaml(cls, path: str) -> "Config":
        """Load configuration from YAML file.
        
        Args:
            path: Path to YAML configuration file.
            
        Returns:
            Config instance with loaded settings.
            
        Raises:
            FileNotFoundError: If the file doesn't exist.
            ImportError: If PyYAML is not installed.
        """
        try:
            import yaml
        except ImportError:
            raise ImportError("PyYAML is required to load YAML config files. "
                            "Install with: pip install pyyaml")
        
        with open(path, 'r') as f:
            data = yaml.safe_load(f)
        
        return cls.from_dict(data or {})
    
    def merge_with(self, other: "Config") -> "Config":
        """Merge another config into this one.
        
        Values from `other` override values in `self`, except for lists
        which are concatenated.
        
        Args:
            other: Config to merge in.
            
        Returns:
            New Config with merged values.
        """
        return Config(
            search_paths=self.search_paths + other.search_paths,
            extra_args=self.extra_args + other.extra_args,
            c_mode=other.c_mode if other.c_mode else self.c_mode,
            enum_to_const=self.enum_to_const + other.enum_to_const,
            ignore_files=self.ignore_files + other.ignore_files,
            output_dir=other.output_dir if other.output_dir != "." else self.output_dir,
            root_namespace=other.root_namespace or self.root_namespace,
            camel_case=other.camel_case,
            type_renames={**self.type_renames, **other.type_renames},
            ignore_types=self.ignore_types + other.ignore_types,
            ignore_fields=self.ignore_fields + other.ignore_fields,
            inheritable_types=self.inheritable_types + other.inheritable_types,
            varargs_functions=self.varargs_functions + other.varargs_functions,
            force_shared_types=self.force_shared_types + other.force_shared_types,
            parallel=other.parallel,
            num_workers=other.num_workers or self.num_workers,
        )


# Global options state for backward compatibility with export_nim_option()
_global_options: dict[str, Any] = {}


def set_global_option(key: str, value: Any) -> None:
    """Set a global option (for backward compatibility).
    
    Args:
        key: Option name.
        value: Option value.
    """
    _global_options[key] = value


def get_global_option(key: str, default: Any = None) -> Any:
    """Get a global option (for backward compatibility).
    
    Args:
        key: Option name.
        default: Default value if not set.
        
    Returns:
        The option value or default.
    """
    return _global_options.get(key, default)


def clear_global_options() -> None:
    """Clear all global options."""
    _global_options.clear()
