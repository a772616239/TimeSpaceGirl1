# Spine Import Skill

This skill provides a documented workflow and utility scripts for importing Spine animations into Unity, specifically handling version incompatibilities and automating the linking process.

## Workflow Summary

1.  **Preparation**:
    *   Rename the `.atlas` file to `.atlas.txt`.
    *   Place all files (`.json`, `.atlas.txt`, `.png`) in a single folder.
2.  **Runtime Patching (If version 3.8.75)**:
    *   Locate `Assets/Spine/Runtime/spine-csharp/SkeletonJson.cs` and `SkeletonBinary.cs`.
    *   Remove the hardcoded check: `if ("3.8.75" == skeletonData.version) throw new Exception(...)`.
3.  **Asset Generation**:
    *   Let Spine-Unity generate the `SkeletonDataAsset` and `SpineAtlasAsset`.
4.  **Automation**:
    *   Use the `SpineImportHelper` menu item to link the atlas and verify the data.

## Utility Script

The `SpineImportHelper.cs` script (found in this folder) adds a menu item under `Tools > Spine > Process Selected Folder` to automate the linking process for a selected folder containing Spine assets.

## Files
- `SKILL.md`: This documentation.
- `SpineImportHelper.cs`: Reusable editor script.
