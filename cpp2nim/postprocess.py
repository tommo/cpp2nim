"""
Post-processing for generated Nim code.

This module provides text replacement utilities for fixing up generated code.
Based on the heavy usage of sub_in_file() in production scripts like genBGFX.py
and genImgui.py, this is a first-class feature of cpp2nim.
"""

import os
import re
import fnmatch
from dataclasses import dataclass, field
from typing import Sequence


@dataclass
class Replacement:
    """A single text replacement rule.
    
    Attributes:
        pattern: The pattern to match (regex or literal).
        replacement: The replacement string.
        mode: Replacement mode:
            - "regex": Regex replacement (all occurrences)
            - "plain": Literal string replacement (all occurrences)
            - "regex_one": Regex replacement (first occurrence only)
            - "plain_one": Literal string replacement (first occurrence only)
    
    Example:
        >>> Replacement("foo", "bar", "plain")  # Replace all "foo" with "bar"
        >>> Replacement(r"\\bint\\b", "cint", "regex")  # Regex replace
    """
    pattern: str
    replacement: str
    mode: str = "regex"  # "regex", "plain", "regex_one", "plain_one"


@dataclass
class PostProcessConfig:
    """Per-file post-processing rules.
    
    Attributes:
        file_pattern: Glob pattern for files to apply rules to (e.g., "*.nim").
        replacements: List of replacement rules.
    
    Example:
        >>> config = PostProcessConfig(
        ...     file_pattern="*_types.nim",
        ...     replacements=[
        ...         Replacement("ptr int", "ptr cint", "plain"),
        ...     ]
        ... )
    """
    file_pattern: str
    replacements: list[Replacement] = field(default_factory=list)


class PostProcessor:
    """Apply text transformations to generated files.
    
    This class provides a structured way to apply post-processing rules
    to generated Nim code, replacing the ad-hoc sub_in_file() calls.
    
    Example:
        >>> processor = PostProcessor([
        ...     PostProcessConfig("*.nim", [
        ...         Replacement("old", "new", "plain"),
        ...     ])
        ... ])
        >>> files = {"test.nim": "old code here"}
        >>> result = processor.process_all(files)
        >>> result["test.nim"]
        'new code here'
    """
    
    def __init__(self, rules: list[PostProcessConfig] | None = None):
        """Initialize the post-processor.
        
        Args:
            rules: List of post-processing configurations.
        """
        self.rules = rules or []
    
    def add_rule(self, file_pattern: str, replacements: list[Replacement]) -> None:
        """Add a post-processing rule.
        
        Args:
            file_pattern: Glob pattern for target files.
            replacements: List of replacement rules.
        """
        self.rules.append(PostProcessConfig(file_pattern, replacements))
    
    def process_file(self, filename: str, content: str) -> str:
        """Apply matching rules to file content.
        
        Args:
            filename: The filename (for matching against patterns).
            content: The file content.
            
        Returns:
            Processed content.
        """
        basename = os.path.basename(filename)
        
        for rule in self.rules:
            if not fnmatch.fnmatch(basename, rule.file_pattern):
                continue
            for repl in rule.replacements:
                content = self._apply_replacement(content, repl)
        
        return content
    
    def process_all(self, files: dict[str, str]) -> dict[str, str]:
        """Process all generated files.
        
        Args:
            files: Dictionary mapping filenames to content.
            
        Returns:
            Dictionary mapping filenames to processed content.
        """
        return {name: self.process_file(name, content)
                for name, content in files.items()}
    
    def _apply_replacement(self, content: str, repl: Replacement) -> str:
        """Apply a single replacement rule.
        
        Args:
            content: The text content.
            repl: The replacement rule.
            
        Returns:
            Modified content.
        """
        if repl.mode == "plain":
            return content.replace(repl.pattern, repl.replacement)
        elif repl.mode == "plain_one":
            return content.replace(repl.pattern, repl.replacement, 1)
        elif repl.mode == "regex_one":
            return re.sub(repl.pattern, repl.replacement, content, count=1)
        else:  # "regex"
            return re.sub(repl.pattern, repl.replacement, content)
    
    @classmethod
    def from_legacy_format(
        cls, 
        replacements: Sequence[tuple[str, ...]] | dict[tuple[str, ...], bool],
        default_mode: str = "regex"
    ) -> "PostProcessor":
        """Convert from legacy sub_in_file format.
        
        This allows existing scripts like genBGFX.py and genImgui.py to work
        with the new PostProcessor class.
        
        Args:
            replacements: Legacy replacement tuples:
                - (pattern, replacement) for default mode
                - (pattern, replacement, mode) for specific mode
            default_mode: Default replacement mode.
            
        Returns:
            PostProcessor configured with the legacy rules.
            
        Example:
            >>> legacy = [
            ...     ('foo', 'bar'),  # Uses default mode
            ...     ('baz', 'qux', 'plain'),  # Uses plain mode
            ... ]
            >>> processor = PostProcessor.from_legacy_format(legacy)
        """
        rules: list[Replacement] = []
        
        # Handle both list and dict formats (dict was used in some scripts)
        if isinstance(replacements, dict):
            items = list(replacements.keys())
        else:
            items = list(replacements)
        
        for item in items:
            if len(item) == 3:
                pattern, replacement, mode = item
            else:
                pattern, replacement = item[0], item[1]
                mode = default_mode
            rules.append(Replacement(pattern, replacement, mode))
        
        # Create a catch-all config that applies to all files
        return cls([PostProcessConfig("*", rules)])


def sub_in_file(
    filename: str, 
    old_to_new: Sequence[tuple[str, ...]] | dict[tuple[str, ...], bool],
    default_mode: str = 'regex'
) -> None:
    """Replace text in a file (backward-compatible function).
    
    This maintains compatibility with existing scripts that use:
        sub_in_file("file.nim", [("old", "new"), ...])
    
    Args:
        filename: Path to the file to modify.
        old_to_new: List of replacement tuples:
            - (pattern, replacement) for default mode
            - (pattern, replacement, mode) for specific mode
        default_mode: Default replacement mode ("regex" or "plain").
    
    Example:
        >>> sub_in_file("output.nim", [
        ...     ("ptr int", "ptr cint", "plain"),
        ...     (r"(\\w+)_Enum", r"\\1", "regex"),
        ... ])
    """
    # Read current content
    os.rename(filename, filename + '.bak')
    with open(filename + '.bak', 'r') as f:
        content = f.read()
    
    # Apply replacements
    processor = PostProcessor.from_legacy_format(old_to_new, default_mode)
    content = processor.process_file(filename, content)
    
    # Write result
    with open(filename + '.new', 'w') as f:
        f.write(content)
    
    os.rename(filename + '.new', filename)
    os.unlink(filename + '.bak')


def append_to_file(filename: str, text: str) -> None:
    """Append text to a file.
    
    Args:
        filename: Path to the file.
        text: Text to append.
    """
    with open(filename, 'a') as f:
        f.write(text)
