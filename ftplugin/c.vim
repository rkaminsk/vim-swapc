if exists("s:done")
    finish
endif
let s:done = 1

if has('python')
    command! -nargs=1 Python python <args>
elseif has('python3')
    command! -nargs=1 Python python3 <args>
else
    echo "Error: Requires Vim compiled with +python or +python3"
    finish
endif

Python << EOF

import vim
import re
import os
import os.path

class Pattern:
    split   = re.compile(r"(\${\w*}|\?{(?:\w+:)?(?:\w+)(?:(?:,\w+)*)})")
    ispath  = re.compile(r"^#{(?P<name>\w+)}$")
    isname  = re.compile(r"^\${(?P<name>\w+)}$")
    isext   = re.compile(r"^\?{(?:(?P<name>\w+):)?(?P<exts>(?:\w+)(?:(?:,\w+)*))}$")
    choices = 0
    def __init__(self, pattern):
        self.__table = {}
        matcher = ["^"]
        checker = []
        for component in pattern.split("/"):
            m = Pattern.ispath.match(component)
            if m is not None:
                name = m.group("name")
                matcher.append("(?P<{0}>.+/|)".format(name))
                checker.append("{{{0}}}".format(name))
                self.__table[name] = None
            else:
                match = []
                check = []
                for part in Pattern.split.split(component):
                    m = Pattern.isname.match(part)
                    if m is not None:
                        name = m.group("name")
                        if not name in self.__table:
                            match.append("(?P<{0}>[^/]*)".format(name))
                            self.__table[name] = None
                        else:
                            match.append("(?P={0})".format(name))
                        check.append("{{{0}}}".format(name))
                    else:
                        m = Pattern.isext.match(part)
                        if m is not None:
                            name = m.group("name")
                            exts = m.group("exts").split(",")
                            if name is None:
                                name = "_choice{0}".format(Pattern.choices)
                                match.append("(?:{0})".format("|".join(exts)))
                                check.append("{{{0}}}".format(name))
                                self.__table[name] = exts
                                Pattern.choices += 1
                            else:
                                match.append("(?P<{0}>{1})".format(name, "|".join(m.group("exts").split(","))))
                                check.append("{{{0}}}".format(name))
                                self.__table[name] = exts
                        else:
                            match.append(re.escape(part))
                            check.append(part)
                match.append("/")
                check.append("/")
                matcher.append("".join(match))
                checker.append("".join(check))
        if len(matcher) > 0 and len(matcher[-1]) > 0 and matcher[-1][-1] == '/':
            matcher[-1] = matcher[-1][:-1]
            checker[-1] = checker[-1][:-1]
        matcher.append("$")
        matcher = "".join(matcher)
        self.__checker = "".join(checker)
        self.__matcher = re.compile(matcher)

    def match(self, path):
        m = self.__matcher.match(path)
        if m is not None:
            return m.groupdict()
        return None

    def check(self, groups):
        replace = {}
        todo = list(self.__table.items())
        def check(i):
            ret = None
            if i < len(todo):
                x, value = todo[i]
                if x in groups:
                    replace[x] = groups[x]
                    ret = check(i + 1)
                elif value is not None:
                    for y in value:
                        replace[x] = y
                        ret = check(i + 1)
                        if ret is not None:
                            break
                else:
                    raise RuntimeError("invalid pattern: no matching key for {0}".format(x))
            else:
                path = self.__checker.format(**replace)
                if os.path.isfile(path):
                    ret = path
            return ret

        return check(0)

class Swapper:
    cache = {}

    def __init__(self):
        self.__pattern_sets = []

    def add(self, patterns):
        self.__pattern_sets.append([Pattern(x) for x in patterns])

    def swap(self, path):
        path = os.path.normpath(path)
        if path in Swapper.cache:
            return Swapper.cache[path]
        for pattern_set in self.__pattern_sets:
            groups = None
            for i in range(len(pattern_set)):
                groups = pattern_set[i].match(path)
                if groups is not None:
                    for pattern in pattern_set[i+1:] + pattern_set[:i]:
                        ret = pattern.check(groups)
                        if ret is not None:
                            Swapper.cache[path] = ret
                            Swapper.cache[ret]  = path
                            return ret
        return None

swapper = Swapper()

def swapc_reset():
    global swapper
    swapper = Swapper()
    if vim.eval('exists("g:swapc_patterns")') == "1":
        m = int(vim.eval('len(g:swapc_patterns)'))
        for i in range(m):
            n = int(vim.eval('len(g:swapc_patterns[{0}])'.format(i)))
            pattern_set = []
            for j in range(n):
                pattern_set.append(vim.eval('g:swapc_patterns[{0}][{1}]'.format(i, j)))
            swapper.add(pattern_set)
    else:
        swapper.add(['#{prefix}/src/#{sub}/${file}.?{cc,c,cpp,cxx,C}', '#{prefix}/include/#{sub}/${file}.?{hh,h,hpp,hxx,H}'])

def swapc():
    global swapper
    path = vim.eval('expand("%")')
    swap = swapper.swap(path)
    if swap is not None:
        escaped = vim.eval('fnameescape("{0}")'.format(swap))
        vim.command('exe' + 'cute "e {0}"'.format(escaped))

swapc_reset()

EOF

command Swapc :Python swapc()
command SwapcReset :Python swapc_reset()
map <Leader>6 :Swapc<CR><c-g>
