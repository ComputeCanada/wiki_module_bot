#!/usr/bin/env python
# -*- coding: utf-8 -*-

# --------------------------------------------------------------------------------------------------------
# IMPORTS
# --------------------------------------------------------------------------------------------------------

import re
import string
def strip_accents(str):
    str = re.sub('[éèê]','e',str)
    str = re.sub('[àâ]','a',str)
    str = re.sub('[îï]','i',str)
    str = re.sub('&','and',str)
    str = re.sub('’','\'',str)
    str = re.sub('\|',' ',str)
    str = ''.join(x for x in str if x in string.printable)
    return str
#def strip_accents(s):
#       return ''.join(c for c in unicodedata.normalize('NFD', unicode(s)) if unicodedata.category(c) != 'Mn')
# --------------------------------------------------------------------------------------------------------
# AUTHORSHIP
# --------------------------------------------------------------------------------------------------------

__author__ = "Maxime Boissonneault (maxime.boissonneault@calculquebec.ca)"
__copyright__ = "Copyright 2013, Calcul Quebec"

# --------------------------------------------------------------------------------------------------------
# GLOBALS
# --------------------------------------------------------------------------------------------------------

MODULE_KEYWORDS = [ 'module-whatis', 'append-path', 'prepend-path', 'conflict', 'prereq', 'setenv', 'set', 'module', 'system' ]
MODULE_CATEGORIES = [ 'apps', 'misc-libs', 'blas-libs', 'compilers', 'tools', 'mpi' ]

def fullstrip(str):
    str = str.strip('\n\r\t -')
    str = re.sub('^-.*','',str)
    str = re.sub('\r','\n',str)
    str = re.sub('\n\n*','\n',str)
    str = re.sub('\n[\t ]*','\n',str)
    return strip_accents(str)


# --------------------------------------------------------------------------------------------------------
# CLASSES
# --------------------------------------------------------------------------------------------------------

class Module:
    def __init__(self, _name, _help, _show = None, _prereq = None, _prereq_list = None, _type = None, wiki_url_list = None):
        self.name = _name
        self.wiki_url_list = wiki_url_list
        self.help = fullstrip('\n'.join(re.sub('\n\n','\n',re.sub('\r\n','\n',_help)).strip('\n').split('\n')[0:]))
        if not self.help:
            self.help = '-'
        if _show:
            self.show = fullstrip(_show)
        else:
            self.show = None
        self.prereq_list = sorted(_prereq_list)
        if not _prereq and _prereq_list:
            self.prereq = " or ".join(self.prereq_list)
        else:
            self.prereq = _prereq
        if _type:
            self.type = _type
        else:
            self.type = None
        self.Parse()

    def Key(self,_key):
        if _key in self.dict:
            return self.dict[_key]
        else:
            return None

    def Parse(self):

        self.dict = {}
        for keyword in MODULE_KEYWORDS:
            self.dict[keyword] = []

        regexp = '\n' + '[ \t]*|\n'.join(MODULE_KEYWORDS) + '[ \t]*'
        if self.show:
            tokens = [ fullstrip(x) for x in re.findall(regexp,self.show) ]
            values = [ fullstrip(x) for x in re.split(regexp,self.show) ]

            for i in range(len(tokens)):
                key = tokens[i]
                self.dict[key].append(values[i+1])
        
        if not self.dict["prereq"] and self.prereq:
            self.dict["prereq"] = self.prereq
        
        if self.show:
            self.site = re.findall('https*://[^ \t\n\r]*',self.show)
        else:
            self.site = re.findall('https*://[^ \t\n\r]*',self.help)


        if self.help:
            self.wikipage = re.findall('CC-Wiki: [^\t\n\r-]*',self.help)
            if isinstance(self.wikipage,list):
                if len(self.wikipage) >= 1:
                    self.wikipage = self.wikipage[0]
                else:
                    self.wikipage = None
            if self.wikipage:
                self.wikipage = " ".join(self.wikipage.split(" ")[1:])

        if not self.wikipage and isinstance(self.wiki_url_list,dict):
            name = self.name.split('/')[0]
            self.wikipage = self.wiki_url_list.get(name,None)

        self.dict['module-whatis'] = fullstrip('\n'.join(self.dict['module-whatis']))
        if False and not self.dict['module-whatis']:
            tmp = re.split("\. ",self.help,1)
            if len(tmp) == 2:
                self.help = tmp[0].strip(" -")
                self.dict['module-whatis'] = tmp[1].strip(" -")
            else:
                tmp = re.split(" - ",self.help,1)
                if len(tmp) == 2:
                    self.help = tmp[0].strip(" -")
                    self.dict['module-whatis'] = tmp[1].strip(" -")
                else:
                    self.dict['module-whatis'] = "-"

        name_split = self.name.split('/')
        if name_split is not None and len(name_split) >= 2:
            self.version = name_split[-1]
            self.app_name = name_split[-2]
            #if the app_name found is within the module categories, try splitting with '-'
            if any(self.app_name.lower() == s.lower() for s in MODULE_CATEGORIES):
                name_split = name_split[-1].split('-')
                if name_split is not None and len(name_split) >= 2:
                    self.app_name = name_split[0]
                    self.version = '-'.join(name_split[1:])
                else:
                    self.version = '-'
                    self.app_name = self.name
        else:
            self.version = '-'
            self.app_name = self.name
        
        if self.site is not None and len(self.site) >= 1:
            self.site = self.site[0]
        else:
            self.site = 'https://www.google.ca/search?q=' + self.app_name

        self.dict['module-load'] = []
        for elem in self.dict['module']:
            listelem = fullstrip(elem).split()
            if listelem is not None and len(listelem) >= 2 and (fullstrip(listelem[0]) == 'load' or fullstrip(listelem[0]) == 'add'):
                self.dict['module-load'].extend(listelem[1:])
        if len(self.dict['module-load']) == 0:
            self.dict['module-load'].append('-')

