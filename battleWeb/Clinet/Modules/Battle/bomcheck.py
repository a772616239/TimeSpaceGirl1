import os
import os.path
import codecs
import sys

def cur_file_dir():
	path = sys.path[0]
	if os.path.isdir(path):
		return path
	elif os.path.isfile(path):
		return os.path.dirname(path)

def checkBom(filename):
	_file = open(os.path.join(parent, filename),'r+')
	data = _file.read()
	if data[:3] == codecs.BOM_UTF8:
		print "the bom file:" + os.path.join(parent, filename)
		_file.seek(0)
		_file.write(data[3:])
		_file.write("   ")
		print "the bom file is modify"
	_file.close()


rootdir = cur_file_dir()

for parent,dirnames,filenames in os.walk(rootdir + '/Logic'):
	for filename in filenames:
		checkBom(filename)

# for parent,dirnames,filenames in os.walk(rootdir + '/res/normal/layout'):
# 	for filename in filenames:
# 		checkBom(filename)

# for parent,dirnames,filenames in os.walk(rootdir + '/res1/normal/layout'):
# 	for filename in filenames:
# 		checkBom(filename)

print "bom finish"