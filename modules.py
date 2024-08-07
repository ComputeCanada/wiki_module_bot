#!/usr/bin/env python

import os
import sys
import json
from xml.etree.ElementTree import ElementTree, Element, SubElement
from xml.sax.saxutils import escape

# For parsing the modulefiles
import re
import pexpect
from Module import Module
import configparser
from packaging.version import parse, InvalidVersion

# --------------------------------------------------------------------------------------------------------
# AUTHORSHIP
# --------------------------------------------------------------------------------------------------------

__author__ = "Maxime Boissonneault (maxime.boissonneault@calculquebec.ca)"
__copyright__ = "Copyright 2013, Calcul Quebec"

OUTPUT_FILE = None
if "-o" in sys.argv:
    try:
        OUTPUT_FILE = sys.argv[sys.argv.index("-o")+1]
    except IndexError:
        print("must specify a filename with -o option", file=sys.stderr)
        sys.exit(1)

CONFIG_FILE = 'module.cfg'
if "-c" in sys.argv:
    try:
        CONFIG_FILE = sys.argv[sys.argv.index("-c")+1]
    except IndexError:
        print("must specify a filename with -c option", file=sys.stderr)
        sys.exit(1)

if "-w" in sys.argv:
    try:
        WIKI_PAGE_LIST = sys.argv[sys.argv.index("-w")+1]
    except IndexError:
        print("must specify a filename with -w option", file=sys.stderr)
        sys.exit(1)

if "-h" in sys.argv or "--h" in sys.argv or "--help" in sys.argv:
    print("Usage : python modules.py [-o <output_file.xml>] [-c <config_file>]", file=sys.stderr)
    sys.exit(1)

# --------------------------------------------------------------------------------------------------------
# GLOBAL FUNCTIONS
# --------------------------------------------------------------------------------------------------------

def parse_wrapper(version):
    try:
        return parse(version)
    except InvalidVersion:
        return parse("0.0")

def ModuleList(paths):
    moduleList = []

    for path in paths:
        os.putenv('MODULEPATH', path)

        output = pexpect.run(MODULE_COMMAND + ' avail')
        splittedOutput = re.split('-* ' + path + ' -*', output)

        if len(splittedOutput) != 2:
            continue

        modules = splittedOutput[1].split()
        for module in modules:
            show = pexpect.run(MODULE_COMMAND + ' show ' + module.replace("(default)",""))
            help = pexpect.run(MODULE_COMMAND + ' help ' + module.replace("(default)",""))
            newModule = Module(module,help,show)
            moduleList.append(newModule)

    return moduleList

def LmodModuleList(paths):
#    try:
    with open(WIKI_PAGE_LIST, "r") as f:
        wiki_url_list = json.loads(f.read())
#    except:
#        print("Error loading the file %s." % WIKI_PAGE_LIST)
#        wiki_url_list = None
    import string
    moduleList = []
    output = pexpect.run(MODULE_COMMAND + ' ' + ':'.join(paths))
    output_js = json.loads(output)
    if "jsonSoftwarePage" in MODULE_COMMAND:
        for elem in output_js:
            for v in elem["versions"]:
                name = v["full"]
                help = "-"
                prereq = "-"
                if "help" in v:
                    help = v["help"]
                if "parent" in v:
                    prereq = " or ".join(v["parent"]).replace("default:","").replace("default","").replace(":"," and ")
                newModule = Module(name,help,"-",prereq)
                if newModule.version[0] != ".":
                    moduleList.append(newModule)
    elif "spider-json" in MODULE_COMMAND:
#        print(str(output_js))
        cnt=0
        for module_name in output_js:
            data = output_js[module_name]
            for path in data:
#                print("    ",path)
                module_data = data[path]
#                print(str(module_data))
                if "fullName" in module_data:
                    name = module_data["fullName"]
                help = "-"
                prereq = "-"
                type = "-"
                if "whatis" in module_data:
                    help = "\n".join(module_data["whatis"])
                if "parentAA" in module_data:
                    prereq = " and ".join(module_data["parentAA"][0])
                if "propT" in module_data and "type_" in module_data["propT"]:
                    type = list(module_data["propT"]["type_"].keys())[0]
                newModule = Module(name,help,"-",_prereq_list=[prereq],_type=type,wiki_url_list=wiki_url_list)
                newModule.name = module_name
                if newModule.version[0] != "." and not module_data.get("hidden") and "whatis" in module_data:
                    found = False
                    new_version = ""
                    for n,m in enumerate(moduleList):
                        if m.name == newModule.name:
                            if newModule.version not in m.version:
                                new_version =  m.version + " " + newModule.version
                            else:
                                new_version = m.version
                            max_version = max(m.version.split(), key=parse_wrapper)
                            if parse_wrapper(max_version) > parse_wrapper(newModule.version):
                                newModule = Module(name,m.help,"-",_prereq_list=(m.prereq_list + [prereq]),_type=type,wiki_url_list=wiki_url_list)
                            else:
                                newModule = Module(name,newModule.help,"-",_prereq_list=(m.prereq_list + [prereq]),_type=type,wiki_url_list=wiki_url_list)
                            newModule.version = new_version
                            newModule.name = module_name
                            moduleList[n] = newModule
                            found = True
                            break
                    if not found:
                        moduleList.append(newModule)
    for n,m in enumerate(moduleList):
        version_str = m.version
        version_list = version_str.split()
        version_sorted = sorted(version_list, key=parse_wrapper)
        m.version = ', '.join([str(elem1) for elem1 in version_sorted])

    return moduleList


# --------------------------------------------------------------------------------------------------------
# MAIN & USAGE
# --------------------------------------------------------------------------------------------------------

def XmlList(list):
    root = Element("root")
    tree = ElementTree(root)
    for module in list:
        mod_e = Element("module")
        e = Element("module_name")
        e.text = escape(module.name)
        mod_e.append(e)
        e = Element("app_name")
        e.text = escape(module.app_name)
        mod_e.append(e)
        e = Element("version")
        e.text = escape(module.version)
        mod_e.append(e)
        e = Element("help")
        e.text = escape(module.help)
        mod_e.append(e)
        e = Element("prereq")
        if module.Key("prereq") is None or len(module.Key("prereq")) == 0:
                e.text = '-'
        else:
            if isinstance(module.Key("prereq"),str):
                e.text = module.Key("prereq")
            else:
                e.text = escape(' '.join(module.Key("prereq")))
        mod_e.append(e)
        e = Element("conflict")
        if module.Key("conflict") is None or len(module.Key("conflict")) == 0:
                e.text = '-'
        else:
                e.text = escape(' '.join(module.Key("conflict")))
        mod_e.append(e)
        e = Element("module-load")
        if module.Key("module-load") is None or len(module.Key("module-load")) == 0:
                e.text = '-'
        else:
                e.text = escape(' '.join(module.Key("module-load")))
        mod_e.append(e)
        e = Element("whatis")
        e.text = module.Key("module-whatis")
        mod_e.append(e)
        e = Element("site")
        e.text = escape(module.site)
        mod_e.append(e)
        e = Element("show")
        e.text = escape(module.show)
        mod_e.append(e)
        e = Element("type")
        if module.type:
            e.text = escape(module.type)
        else:
            e.text = ""
        mod_e.append(e)
        e = Element("wikipage")
        if module.wikipage:
            e.text = escape(module.wikipage)
        else:
            e.text = ""
        mod_e.append(e)

        root.append(mod_e)

    if OUTPUT_FILE is not None:
        tree.write(OUTPUT_FILE,'utf-8')
    else:
        tree.write(sys.stdout,'utf-8')

def Main(argv_):
    """Main function."""
    if MODULE_STYLE == "module":
        list = ModuleList(MODULE_PATHS)
    else:
        list = LmodModuleList(MODULE_PATHS)
    list = sorted(list,key=lambda mod: mod.version.lower())
    list = sorted(list,key=lambda mod: mod.app_name.lower())
    list = sorted(list,key=lambda mod: mod.name.lower())
    XmlList(list)

# --------------------------------------------------------------------------------------------------------
# GLOBAL NAMES
# --------------------------------------------------------------------------------------------------------

Config = configparser.ConfigParser()
Config.read(CONFIG_FILE)
section = 'Configuration'
MODULE_COMMAND = Config.get(section,'command')
MODULE_PATHS = Config.get(section,'paths').split(':')
try:
    MODULE_STYLE = Config.get(section,'style') or "module"
except:
    MODULE_STYLE = "module"

if __name__ == "__main__":
    Main(sys.argv[ 1: ])

