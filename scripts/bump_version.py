import re
import os
import sys
import argparse

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("release_type", choices=["patch", "minor", "major"])
    args = parser.parse_args()
    
    file_path = "pubspec.yaml"
    release_type = args.release_type

    print(f"Processing {file_path} with release type: {release_type}")

    try:
        with open(file_path, "r") as f:
            content = f.read()
    except FileNotFoundError:
        print(f"Error: File not found at {file_path}")
        sys.exit(1)

    # Match 'version: 1.0.0+1'
    version_pattern = r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)'
    
    match = re.search(version_pattern, content, re.MULTILINE)
    if not match:
        print("Error: Could not find version pattern in pubspec.yaml.")
        sys.exit(1)

    full_match = match.group(0)
    major = int(match.group(1))
    minor = int(match.group(2))
    patch = int(match.group(3))
    build = int(match.group(4))
    
    current_version = f"{major}.{minor}.{patch}+{build}"
    print(f"Current Version: {current_version}")

    if release_type == "major":
        major += 1
        minor = 0
        patch = 0
    elif release_type == "minor":
        minor += 1
        patch = 0
    else: # patch
        patch += 1
    
    build += 1
    
    new_version = f"{major}.{minor}.{patch}"
    new_version_full = f"{new_version}+{build}"
    print(f"New Version: {new_version_full}")
    
    new_line = f"version: {new_version_full}"
    content = content.replace(full_match, new_line)

    with open(file_path, "w") as f:
        f.write(content)

    # Set output for GitHub Actions
    if "GITHUB_OUTPUT" in os.environ:
        with open(os.environ["GITHUB_OUTPUT"], "a") as f:
            f.write(f"new_version={new_version}\n")
            f.write(f"new_version_full={new_version_full}\n")
    else:
        print(f"GITHUB_OUTPUT not set. New version is: {new_version_full}")

if __name__ == "__main__":
    main()
