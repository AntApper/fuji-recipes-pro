#!/usr/bin/env python3
"""
generate-xcode-projects.py
Generate .xcodeproj files for FujiRecipes iOS and FujiRecipesMac apps.

Usage:
    cd /path/to/fuji-recipes-research
    python3 tools/generate-xcode-projects.py

Creates:
    FujiRecipes/iOS/FujiRecipes.xcodeproj/project.pbxproj
    FujiRecipesMac/macos/FujiRecipesMac.xcodeproj/project.pbxproj
"""

import hashlib
import os
import sys
import textwrap
from datetime import datetime

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def hash_id(text: str) -> str:
    """Generate a consistent 24-char hex ID from text (Xcode project style)."""
    return hashlib.md5(text.encode()).hexdigest()[:24].upper()


def make_pbxproj(platform: str, app_name: str, bundle_id: str, product_type: str) -> str:
    """
    Generate a minimal but functional project.pbxproj file.

    Args:
        platform: "ios" or "macos"
        app_name: e.g. "FujiRecipes"
        bundle_id: e.g. "com.ant.fuji-recipes"
        product_type: "com.apple.product-type.application" for iOS or macOS app
    """
    # IDs — deterministic from names
    proj_id = hash_id(f"{app_name}-project")
    main_group_id = hash_id("main-group")
    products_group_id = hash_id("products-group")
    sources_group_id = hash_id("sources-group")
    app_target_id = hash_id("app-target")
    ns_ref_id = hash_id("ns-ref")
    core_ref_id = hash_id("core-ref")
    ptp_ref_id = hash_id("ptp-ref")

    now = datetime.now()

    if platform == "ios":
        min_version = "17.0"
        sdk = "iphoneos"
        arch = "arm64"
        device_dir = "iPhoneOS"
        deploy = "DeploymentTarget"
    else:
        min_version = "14.0"
        sdk = "macosx"
        arch = "arm64;x86_64"
        device_dir = "MacOSX"
        deploy = "MACOSX_DEPLOYMENT_TARGET"

    pbxproj = textwrap.dedent(f"""\
    // !$*UTF8*$!
    {{
        archiveVersion = 1;
        classes = {{
        }};
        objectVersion = 56;
        objects = {{

    /* Begin PBXBuildFile section */
            {hash_id("app-swift-file")} /* App.swift in Sources */ = {{isa = PBXBuildFile; sourceTree = "<group>"; }};
    /* End PBXBuildFile section */

    /* Begin PBXFileReference section */
            {hash_id("app-exe")} /* {app_name}.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = {app_name}.app; sourceTree = BUILT_PRODUCTS_DIR; }};
            {hash_id("app-swift-ref")} /* App.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = App.swift; sourceTree = "<group>"; }};
    /* End PBXFileReference section */

    /* Begin PBXGroup section */
            {main_group_id} = {{
                isa = PBXGroup;
                children = (
                    {sources_group_id},
                    {products_group_id},
                );
                sourceTree = "<group>";
            }};
            {products_group_id} = {{
                isa = PBXGroup;
                children = (
                    {hash_id("app-exe")},
                );
                name = Products;
                sourceTree = "<group>";
            }};
            {sources_group_id} = {{
                isa = PBXGroup;
                children = (
                    {hash_id("app-swift-ref")},
                );
                path = Source;
                sourceTree = "<group>";
            }};
    /* End PBXGroup section */

    /* Begin PBXNativeTarget section */
            {app_target_id} = {{
                isa = PBXNativeTarget;
                buildConfigurationList = {hash_id("proj-conf")};
                buildPhases = (
                    {hash_id("sources-phase")},
                    {hash_id("frameworks-phase")},
                );
                buildRules = (
                );
                dependencies = (
                );
                name = {app_name};
                productName = {app_name};
                productReference = {hash_id("app-exe")};
                productType = "{product_type}";
            }};
    /* End PBXNativeTarget section */

    /* Begin PBXProject section */
            {proj_id} = {{
                isa = PBXProject;
                attributes = {{
                    BuildIndependentTargetsInParallel = 1;
                    LastSwiftUpdateCheck = 1500;
                    LastUpgradeCheck = 1500;
                    TargetAttributes = {{
                        {app_target_id} = {{
                            CreatedOnToolsVersion = 15.0;
                        }};
                    }};
                }};
                buildConfigurationList = {hash_id("proj-conf")};
                compatibilityVersion = "Xcode 14.0";
                developmentRegion = en;
                hasScannedForEncodings = 0;
                knownRegions = (
                    en,
                    Base,
                );
                mainGroup = {main_group_id};
                productRefGroup = {products_group_id};
                projectRoot = "";
                targets = (
                    {app_target_id},
                );
            }};
    /* End PBXProject section */

    /* Begin PBXSourcesBuildPhase section */
            {hash_id("sources-phase")} = {{
                isa = PBXSourcesBuildPhase;
                buildActionMask = 2147483647;
                files = (
                    {hash_id("app-swift-file")},
                );
                runOnlyForDeploymentPostprocessing = 0;
            }};
    /* End PBXSourcesBuildPhase section */

    /* Begin PBXFrameworksBuildPhase section */
            {hash_id("frameworks-phase")} = {{
                isa = PBXFrameworksBuildPhase;
                buildActionMask = 2147483647;
                files = (
                );
                runOnlyForDeploymentPostprocessing = 0;
            }};
    /* End PBXFrameworksBuildPhase section */

    /* Begin XCBuildConfiguration section */
            {hash_id("debug-conf")} = {{
                isa = XCBuildConfiguration;
                buildSettings = {{
                    ALWAYS_SEARCH_USER_PATHS = NO;
                    CLANG_ANALYZER_NONNULL = YES;
                    CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
                    CLANG_ENABLE_MODULES = YES;
                    CLANG_ENABLE_OBJC_ARC = YES;
                    {deploy} = "{min_version}";
                    COPY_PHASE_STRIP = NO;
                    DEBUG_INFORMATION_FORMAT = dwarf;
                    ENABLE_STRICT_OBJC_MSGSEND = YES;
                    {deploy}_ENABLED = NO;
                    GCC_OPTIMIZATION_LEVEL = 0;
                    GCC_PRECOMPILE_PREFIX_HEADER = YES;
                    GCC_WARN_ABOUT_RETURN_TYPE = YES;
                    GCC_WARN_UNINITIALIZED_AUTOS = YES;
                    MODULE_BUNDLE_ID = "{bundle_id}";
                    PRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";
                    PRODUCT_NAME = "{app_name}";
                    SWIFT_EMIT_LOC_STRINGS = YES;
                    SWIFT_OPTIMIZATION_LEVEL = "-Onone";
                    SWIFT_VERSION = 6.0;
                }};
                name = Debug;
            }};
            {hash_id("release-conf")} = {{
                isa = XCBuildConfiguration;
                buildSettings = {{
                    ALWAYS_SEARCH_USER_PATHS = NO;
                    CLANG_ANALYZER_NONNULL = YES;
                    CLANG_CXX_LANGUAGE_STANDARD = "gnu++20";
                    CLANG_ENABLE_MODULES = YES;
                    CLANG_ENABLE_OBJC_ARC = YES;
                    {deploy} = "{min_version}";
                    COPY_PHASE_STRIP = NO;
                    DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
                    ENABLE_NS_ASSERTIONS = NO;
                    ENABLE_STRICT_OBJC_MSGSEND = YES;
                    {deploy}_ENABLED = NO;
                    GCC_WARN_ABOUT_RETURN_TYPE = YES;
                    GCC_WARN_UNINITIALIZED_AUTOS = YES;
                    MODULE_BUNDLE_ID = "{bundle_id}";
                    PRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";
                    PRODUCT_NAME = "{app_name}";
                    SWIFT_EMIT_LOC_STRINGS = YES;
                    SWIFT_VERSION = 6.0;
                }};
                name = Release;
            }};
            {hash_id("proj-conf")} = {{
                isa = XCBuildConfiguration;
                buildSettings = {{
                    ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
                    CODE_SIGN_STYLE = Automatic;
                    DEVELOPMENT_TEAM = "";
                    {("IPHONE_DEPLOYMENT_TARGET" if platform == "ios" else deploy)} = "{min_version}";
                    INFOPLIST_FILE = Info.plist;
                    LD_RUNPATH_SEARCH_PATHS = (
                        "$(inherited)",
                        "@executable_path/Frameworks",
                    );
                    PRODUCT_BUNDLE_IDENTIFIER = "{bundle_id}";
                    PRODUCT_NAME = "{app_name}";
                    SWIFT_EMIT_LOC_STRINGS = YES;
                    SWIFT_VERSION = 6.0;
                    {("TARGETED_DEVICE_FAMILY" if platform == "ios" and platform == "ios" else "")} = "{('1,2' if platform == 'ios' else '')}";
                }};
                name = Release;
            }};
    /* End XCBuildConfiguration section */

    /* Begin XCConfigurationList section */
            {hash_id("proj-conf")} = {{
                isa = XCConfigurationList;
                buildConfigurations = (
                    {hash_id("debug-conf")},
                    {hash_id("release-conf")},
                );
                defaultConfigurationIsVisible = 0;
                defaultConfigurationName = Release;
            }};
    /* End XCConfigurationList section */

        }};
        rootObject = {proj_id};
    }}
    """)

    return pbxproj


def generate_ios_project():
    """Generate the iOS Xcode project."""
    pbxproj = make_pbxproj(
        platform="ios",
        app_name="FujiRecipes",
        bundle_id="com.ant.fuji-recipes",
        product_type="com.apple.product-type.application",
    )

    project_dir = os.path.join(PROJECT_ROOT, "FujiRecipes", "iOS", "FujiRecipes.xcodeproj")
    os.makedirs(project_dir, exist_ok=True)

    proj_path = os.path.join(project_dir, "project.pbxproj")
    with open(proj_path, "w") as f:
        f.write(pbxproj)

    print(f"  ✅ iOS project: {proj_path}")
    return proj_path


def generate_macos_project():
    """Generate the macOS Xcode project."""
    pbxproj = make_pbxproj(
        platform="macos",
        app_name="FujiRecipesMac",
        bundle_id="com.ant.fuji-recipes-mac",
        product_type="com.apple.product-type.application",
    )

    project_dir = os.path.join(PROJECT_ROOT, "FujiRecipesMac", "macos", "FujiRecipesMac.xcodeproj")
    os.makedirs(project_dir, exist_ok=True)

    proj_path = os.path.join(project_dir, "project.pbxproj")
    with open(proj_path, "w") as f:
        f.write(pbxproj)

    print(f"  ✅ macOS project: {proj_path}")
    return proj_path


def generate_workspace():
    """Generate the Xcode workspace file."""
    workspace_xml = textwrap.dedent("""\
        <?xml version="1.0" encoding="UTF-8"?>
        <workspace
            format="1.0"
            label="FujiRecipes"
            supportsMultipleConcurrentModifiers="YES"
            supportsMultipleConcurrentScenes="YES">
            <object id="1" class="XCWorkspaceArtifact">
                <children>
                    <object id="2" class="XCWorkspaceArtifactDirectory" name="Packages">
                        <children>
                            <object id="3" class="XCWorkspaceArtifactFile" ref="pkgFujiRecipesCore">
                                <location type="file" ref="pkgFujiRecipesCore"/>
                            </object>
                            <object id="4" class="XCWorkspaceArtifactFile" ref="pkgFujiPTPClient">
                                <location type="file" ref="pkgFujiPTPClient"/>
                            </object>
                        </children>
                    </object>
                    <object id="5" class="XCWorkspaceArtifactDirectory" name="Projects">
                        <children>
                            <object id="6" class="XCWorkspaceArtifactFile" ref="iosProject">
                                <location type="file" ref="iosProject"/>
                            </object>
                            <object id="7" class="XCWorkspaceArtifactFile" ref="macosProject">
                                <location type="file" ref="macosProject"/>
                            </object>
                        </children>
                    </object>
                </children>
            </object>
        </workspace>
        """)

    workspace_dir = os.path.join(PROJECT_ROOT)
    ws_path = os.path.join(workspace_dir, "FujiRecipes.xcworkspace", "contents.xcworkspace")
    os.makedirs(os.path.dirname(ws_path), exist_ok=True)

    with open(ws_path, "w") as f:
        f.write(workspace_xml)

    print(f"  ✅ Workspace: {ws_path}")
    return ws_path


def main():
    print("🔨 Scaffolding Fuji Recipes Xcode projects...")
    print()

    ios_proj = generate_ios_project()
    macos_proj = generate_macos_project()
    workspace = generate_workspace()

    print()
    print("📁 Project structure:")
    print(f"    FujiRecipesCore/       ← SPM: models, enums, PTP mapping")
    print(f"    FujiPTPClient/         ← SPM: PTP protocol + platform stubs")
    print(f"    FujiRecipes/iOS/       ← iOS Xcode project")
    print(f"    FujiRecipesMac/macos/  ← macOS Xcode project")
    print(f"    FujiRecipes.xcworkspace/ ← Workspace")
    print()
    print("⚠️  Notes:")
    print("   1. Set your DEVELOPMENT_TEAM (signing certificate) in each project")
    print("   2. iOS requires an Apple Developer account for camera access entitlements")
    print("   3. Add FujiRecipesCore and FujiPTPClient as package dependencies in each app target")
    print("   4. The app source files (App.swift) were created in Source/ subdirs")
    print()
    print("   Open the workspace:")
    print(f"   open {PROJECT_ROOT}/FujiRecipes.xcworkspace")


if __name__ == "__main__":
    main()
