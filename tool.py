import os
import os.path
import re

def sub_in_file(filename, oldToNew, defaultMode = 'regex'):
    """
    I replace the text `oldstr' with `newstr' in `filename' using sed
    and mv.
    """
    os.rename(filename, filename+'.bak')
    f = open(filename+'.bak')
    d = f.read()
    f.close()
    for pair in oldToNew:
        if len(pair) == 3:
            k,v,t = pair
        else:
            k,v = pair
            t = defaultMode

        if t == 'plain':
            d = d.replace(k, v)
        else:
            d = re.sub(k,v,d)

    f = open(filename + '.new', 'w')
    f.write(d)
    f.close()
    os.rename(filename+'.new', filename)
    os.unlink(filename+'.bak')

def append_to_file( filename, string ):
    f = open(filename, 'a')
    f.write(string)
    f.close()
