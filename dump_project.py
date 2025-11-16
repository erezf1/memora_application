# Python Script to Dump Project Files to a Single Text File

import os

# --- CONFIGURATION ---
# The root directory of your Flutter project.
project_root = r"C:\Users\efeig\flutter projects\MemoraApplication\memora_application"

# The name of the output file. It will be created in the project root.
output_file = os.path.join(project_root, "project_dump.txt")

# The specific subdirectories you want to include in the dump.
directories_to_scan = [
    "lib",
    "android",
    "documents"
]

# The file extensions to look for. This helps filter out irrelevant files.
# Using a tuple is a common practice for `endswith`.
file_extensions_to_include = (
    ".dart",
    ".kt",
    ".java",
    ".xml",
    ".gradle",
    ".kts",
    ".txt",
    ".yaml"  # Includes pubspec.yaml
)
# --- END CONFIGURATION ---

print("Starting project dump...")

# Open the output file in write mode ('w') to clear it and start fresh.
# Use utf-8 encoding for broad compatibility.
with open(output_file, 'w', encoding='utf-8') as f_out:
    # Iterate through the specified directories
    for dir_to_scan in directories_to_scan:
        full_dir_path = os.path.join(project_root, dir_to_scan)
        
        # os.walk recursively goes through every file and folder.
        for dirpath, _, filenames in os.walk(full_dir_path):
            for filename in filenames:
                if filename.endswith(file_extensions_to_include):
                    full_file_path = os.path.join(dirpath, filename)
                    # Get the path relative to the project root for the header.
                    relative_path = os.path.relpath(full_file_path, project_root)
                    
                    print(f"Dumping: {relative_path}")
                    
                    f_out.write(f"==================== FILE: {relative_path} ====================\n")
                    
                    # Read the source file and write its content to the dump file.
                    with open(full_file_path, 'r', encoding='utf-8', errors='ignore') as f_in:
                        f_out.write(f_in.read())
                        f_out.write("\n\n") # Add blank lines for spacing

print(f"Project dump completed successfully. Output file: {output_file}")