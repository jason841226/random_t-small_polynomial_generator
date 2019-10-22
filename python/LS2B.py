import sys
fr = open(sys.argv[1], "r")
fw = open(sys.argv[2], "w")
for line in fr:
	if(line[0]!='/'):
		fw.write(line[-3:])