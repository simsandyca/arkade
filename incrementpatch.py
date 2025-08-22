#!/usr/bin/python3

import sys

def increment_patch_version(version_string):
    """
    Increments the patch version of a semantic version string (X.Y.Z).

    Args:
        version_string (str): The semantic version string (e.g., "1.2.3").

    Returns:
        str: The incremented version string (e.g., "1.2.4").
    """
    parts = version_string.split('.')
    if len(parts) != 3:
        raise ValueError("Invalid semantic version format. Expected X.Y.Z")

    try:
        major = int(parts[0])
        minor = int(parts[1])
        patch = int(parts[2])
    except ValueError:
        raise ValueError("Version components must be integers.")

    patch += 1
    return f"{major}.{minor}.{patch}"

# Example usage:
current_version = sys.argv[1]
new_version = increment_patch_version(current_version)
print(new_version)
