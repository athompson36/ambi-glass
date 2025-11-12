#!/usr/bin/env python3
"""
Script to configure Watch Remote Addon files in Xcode project
Adds files to build phases, configures target memberships, and adds frameworks
"""

import re
import sys
import os
from pathlib import Path

PROJECT_FILE = Path(__file__).parent.parent / "ios/AmbiStudio/AmbiStudio.xcodeproj/project.pbxproj"

# File UUIDs from project (already referenced)
FILE_UUIDS = {
    "RemoteProtocol.swift": "49CE7F722EC3F00100A1FB94",
    "LANListener.swift": "49CE7F712EC3F00100A1FB94",
    "PhoneRelay.swift": "49CE7F702EC3EFF200A1FB94",
    "WatchRemote.swift": "49CE7F732EC3F01800A1FB94",
    "WatchTransportView.swift": "49CE7F742EC3F01800A1FB94",
}

# Target UUIDs
AMBI_STUDIO_TARGET = "49ED2F312EBE999C0000CC31"
AMBI_STUDIO_SOURCES_PHASE = "49ED2F2E2EBE999C0000CC31"
AMBI_STUDIO_FRAMEWORKS_PHASE = "49ED2F2F2EBE999C0000CC31"

def generate_build_file_uuid(file_uuid):
    """Generate a PBXBuildFile UUID from file UUID"""
    # Simple hash-based UUID generation (first 24 chars of file UUID)
    return file_uuid[:24] + "0000CC32"

def add_files_to_build_phase(content):
    """Add Watch Remote files to AmbiStudio target build phases"""
    
    # Find the Sources build phase
    sources_pattern = rf'({AMBI_STUDIO_SOURCES_PHASE} /\* Sources \*/ = \{{[^}}]*files = \([\s\S]*?)(\t\t\t\);)'
    
    match = re.search(sources_pattern, content)
    if not match:
        print("❌ Could not find Sources build phase")
        return content
    
    files_section = match.group(1)
    closing = match.group(2)
    
    # Check which files are already added
    existing_files = set()
    for file_uuid in FILE_UUIDS.values():
        build_file_uuid = generate_build_file_uuid(file_uuid)
        if build_file_uuid in files_section:
            existing_files.add(file_uuid)
    
    # Add missing files
    new_entries = []
    for filename, file_uuid in FILE_UUIDS.items():
        if file_uuid not in existing_files:
            build_file_uuid = generate_build_file_uuid(file_uuid)
            # Only add SharedRemote and iOS-Relay to AmbiStudio (iPhone) target
            if "RemoteProtocol" in filename or "LANListener" in filename or "PhoneRelay" in filename:
                new_entries.append(f'\t\t\t\t{build_file_uuid} /* {filename} in Sources */,')
    
    if new_entries:
        # Insert before closing parenthesis
        files_section = files_section.rstrip() + "\n" + "\n".join(new_entries) + "\n"
        content = content[:match.start()] + files_section + closing + content[match.end():]
        print(f"✅ Added {len(new_entries)} files to Sources build phase")
    else:
        print("ℹ️  All files already in Sources build phase")
    
    return content

def add_pbx_build_file_section(content):
    """Add PBXBuildFile entries for new files"""
    
    # Find PBXBuildFile section
    build_file_pattern = r'(/\* Begin PBXBuildFile section \*/[\s\S]*?)(/\* End PBXBuildFile section \*/)'
    
    match = re.search(build_file_pattern, content)
    if not match:
        print("❌ Could not find PBXBuildFile section")
        return content
    
    build_file_section = match.group(1)
    end_marker = match.group(2)
    
    # Check which build file entries exist
    new_entries = []
    for filename, file_uuid in FILE_UUIDS.items():
        build_file_uuid = generate_build_file_uuid(file_uuid)
        if build_file_uuid not in build_file_section:
            # Only add for files that go in AmbiStudio target
            if "RemoteProtocol" in filename or "LANListener" in filename or "PhoneRelay" in filename:
                new_entries.append(f'\t\t{build_file_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_uuid} /* {filename} */; }};')
    
    if new_entries:
        build_file_section = build_file_section.rstrip() + "\n" + "\n".join(new_entries) + "\n"
        content = content[:match.start()] + build_file_section + end_marker + content[match.end():]
        print(f"✅ Added {len(new_entries)} PBXBuildFile entries")
    else:
        print("ℹ️  All PBXBuildFile entries already exist")
    
    return content

def add_frameworks(content):
    """Add WatchConnectivity and Network frameworks"""
    
    # Find Frameworks build phase
    frameworks_pattern = rf'({AMBI_STUDIO_FRAMEWORKS_PHASE} /\* Frameworks \*/ = \{{[^}}]*files = \([\s\S]*?)(\t\t\t\);)'
    
    match = re.search(frameworks_pattern, content)
    if not match:
        print("❌ Could not find Frameworks build phase")
        return content
    
    frameworks_section = match.group(1)
    closing = match.group(2)
    
    # Check if frameworks are already added
    has_watchconnectivity = "WatchConnectivity" in frameworks_section
    has_network = "Network" in frameworks_section
    
    new_entries = []
    if not has_watchconnectivity:
        # Generate UUID for framework
        wc_uuid = "49CE7F752EC3F01800A1FB94"
        new_entries.append(f'\t\t\t\t{wc_uuid} /* WatchConnectivity.framework in Frameworks */,')
    
    if not has_network:
        # Generate UUID for framework
        net_uuid = "49CE7F762EC3F01800A1FB94"
        new_entries.append(f'\t\t\t\t{net_uuid} /* Network.framework in Frameworks */,')
    
    if new_entries:
        frameworks_section = frameworks_section.rstrip() + "\n" + "\n".join(new_entries) + "\n"
        content = content[:match.start()] + frameworks_section + closing + content[match.end():]
        print(f"✅ Added {len(new_entries)} frameworks")
    else:
        print("ℹ️  Frameworks already added")
    
    return content

def main():
    if not PROJECT_FILE.exists():
        print(f"❌ Project file not found: {PROJECT_FILE}")
        sys.exit(1)
    
    print(f"📝 Reading project file: {PROJECT_FILE}")
    with open(PROJECT_FILE, 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("\n🔧 Configuring Watch Remote Addon...\n")
    
    # Add PBXBuildFile entries
    content = add_pbx_build_file_section(content)
    
    # Add files to Sources build phase
    content = add_files_to_build_phase(content)
    
    # Add frameworks
    content = add_frameworks(content)
    
    # Write back
    backup_file = PROJECT_FILE.with_suffix('.pbxproj.backup')
    print(f"\n💾 Creating backup: {backup_file}")
    with open(backup_file, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ Writing updated project file...")
    with open(PROJECT_FILE, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("\n✅ Configuration complete!")
    print("\n⚠️  Note: This script only configures the main AmbiStudio target.")
    print("   For watchOS target, you'll need to create it manually in Xcode:")
    print("   1. File → New → Target → watchOS → App")
    print("   2. Name: AmbiGlassWatch")
    print("   3. Add watchOS-App files to that target")
    print("\n⚠️  Also add Info.plist entry manually:")
    print("   Key: Privacy - Local Network Usage Description")
    print("   Value: AmbiGlass needs network access to relay remote control commands")

if __name__ == "__main__":
    main()

