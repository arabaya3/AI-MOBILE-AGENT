"""Adds dev/staging/prod build configurations and schemes to the iOS project. Idempotent.

Usage: python tool/configure_ios_flavors.py
"""

import hashlib
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "ios"
PBXPROJ = ROOT / "Runner.xcodeproj/project.pbxproj"
SCHEMES = ROOT / "Runner.xcodeproj/xcshareddata/xcschemes"

BUNDLE_ID = "com.teia.aiassistant"
DEPLOYMENT_TARGET = "15.0"
FLAVORS = {
    "dev": {"suffix": ".dev", "name": "TEIA AI Dev"},
    "staging": {"suffix": ".staging", "name": "TEIA AI Staging"},
    "prod": {"suffix": "", "name": "TEIA AI"},
}
BASE_NAMES = ("Debug", "Release", "Profile")

ATS_SCRIPT_ID = "5EA7A1D2C0FFEE0000000001"


def new_id(seed: str) -> str:
    return hashlib.sha1(seed.encode()).hexdigest()[:24].upper()


def set_setting(block: str, key: str, value: str) -> str:
    line = f"\t\t\t\t{key} = {value};\n"
    pattern = re.compile(rf"^\t\t\t\t{re.escape(key)} = .*?;\n", re.M)
    if pattern.search(block):
        return pattern.sub(line.replace("\\", "\\\\"), block)
    return block.replace("\t\t\tbuildSettings = {\n", "\t\t\tbuildSettings = {\n" + line, 1)


def configure_runner_settings(block: str, flavor: str) -> str:
    spec = FLAVORS[flavor]
    block = set_setting(block, "PRODUCT_BUNDLE_IDENTIFIER", BUNDLE_ID + spec["suffix"])
    block = set_setting(block, "APP_DISPLAY_NAME", f'"{spec["name"]}"')
    block = set_setting(block, "APP_FLAVOR", flavor)
    return block


def main() -> None:
    text = PBXPROJ.read_text(encoding="utf-8")
    text = text.replace("IPHONEOS_DEPLOYMENT_TARGET = 13.0;", f"IPHONEOS_DEPLOYMENT_TARGET = {DEPLOYMENT_TARGET};")
    text = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = com\.teia\.teiaAi\.RunnerTests;", f"PRODUCT_BUNDLE_IDENTIFIER = {BUNDLE_ID}.RunnerTests;", text)

    blocks = {
        m.group(1): m.group(0)
        for m in re.finditer(r"\t\t([0-9A-F]{24}) /\* (\w+) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};\n", text, re.S)
    }
    runner_list = re.search(r'/\* Build configuration list for PBXNativeTarget "Runner" \*/ = \{.*?\);', text, re.S).group(0)
    runner_ids = set(re.findall(r"([0-9A-F]{24}) /\*", runner_list))

    for config_id, block in blocks.items():
        if config_id in runner_ids:
            text = text.replace(block, configure_runner_settings(block, "prod"))
    blocks = {
        m.group(1): m.group(0)
        for m in re.finditer(r"\t\t([0-9A-F]{24}) /\* (\w+) \*/ = \{\n\t\t\tisa = XCBuildConfiguration;.*?\n\t\t\};\n", text, re.S)
    }

    if "/* Debug-dev */" not in text:
        new_blocks = []
        list_additions: dict[str, list[str]] = {}
        for config_id, block in blocks.items():
            base = re.search(r"\n\t\t\tname = (\w+);", block).group(1)
            if base not in BASE_NAMES:
                continue
            for flavor in FLAVORS:
                name = f"{base}-{flavor}"
                fid = new_id(config_id + name)
                copy = block.replace(f"\t\t{config_id} /* {base} */", f"\t\t{fid} /* {name} */", 1)
                copy = copy.replace(f"\n\t\t\tname = {base};", f'\n\t\t\tname = "{name}";')
                if config_id in runner_ids:
                    copy = configure_runner_settings(copy, flavor)
                new_blocks.append(copy)
                list_additions.setdefault(config_id, []).append(f"\t\t\t\t{fid} /* {name} */,\n")

        marker = "/* End XCBuildConfiguration section */"
        text = text.replace(marker, "".join(new_blocks) + marker, 1)
        for config_id, lines in list_additions.items():
            entry = re.search(rf"\t\t\t\t{config_id} /\* \w+ \*/,\n", text.split("/* Begin XCConfigurationList section */")[1]).group(0)
            section_start = text.index("/* Begin XCConfigurationList section */")
            pos = text.index(entry, section_start) + len(entry)
            text = text[:pos] + "".join(lines) + text[pos:]

    if ATS_SCRIPT_ID not in text:
        script = (
            f"\t\t{ATS_SCRIPT_ID} /* Allow local networking (dev only) */ = {{\n"
            "\t\t\tisa = PBXShellScriptBuildPhase;\n"
            "\t\t\talwaysOutOfDate = 1;\n"
            "\t\t\tbuildActionMask = 2147483647;\n"
            "\t\t\tfiles = (\n\t\t\t);\n"
            "\t\t\tinputPaths = (\n\t\t\t);\n"
            '\t\t\tname = "Allow local networking (dev only)";\n'
            "\t\t\toutputPaths = (\n\t\t\t);\n"
            "\t\t\trunOnlyForDeploymentPostprocessing = 0;\n"
            "\t\t\tshellPath = /bin/sh;\n"
            '\t\t\tshellScript = "if [ \\"${APP_FLAVOR}\\" = \\"dev\\" ]; then\\n'
            '  PLIST=\\"${TARGET_BUILD_DIR}/${INFOPLIST_PATH}\\"\\n'
            '  /usr/libexec/PlistBuddy -c \\"Delete :NSAppTransportSecurity\\" \\"$PLIST\\" 2>/dev/null || true\\n'
            '  /usr/libexec/PlistBuddy -c \\"Add :NSAppTransportSecurity dict\\" \\"$PLIST\\"\\n'
            '  /usr/libexec/PlistBuddy -c \\"Add :NSAppTransportSecurity:NSAllowsLocalNetworking bool true\\" \\"$PLIST\\"\\n'
            'fi\\n";\n'
            "\t\t};\n"
        )
        text = text.replace("/* End PBXShellScriptBuildPhase section */", script + "/* End PBXShellScriptBuildPhase section */", 1)
        runner_target = re.search(r'/\* Runner \*/ = \{\n\t\t\tisa = PBXNativeTarget;.*?buildPhases = \(\n(.*?)\t\t\t\);', text, re.S)
        phases = runner_target.group(1)
        text = text.replace(phases, phases + f"\t\t\t\t{ATS_SCRIPT_ID} /* Allow local networking (dev only) */,\n", 1)

    PBXPROJ.write_text(text, encoding="utf-8", newline="\n")

    runner_scheme = (SCHEMES / "Runner.xcscheme").read_text(encoding="utf-8")
    for flavor in FLAVORS:
        scheme = runner_scheme
        for base in BASE_NAMES:
            scheme = scheme.replace(f'buildConfiguration = "{base}"', f'buildConfiguration = "{base}-{flavor}"')
        (SCHEMES / f"{flavor}.xcscheme").write_text(scheme, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
