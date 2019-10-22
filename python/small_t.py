import sys
fr = open(sys.argv[1], "r")
fw = open(sys.argv[2],"w")
t = 100
l = [line for line in fr]
for idx in range(1024):
	if idx < 2*t:
		l[idx] = l[idx][:-2]+"1"
	else:
		l[idx] = l[idx][:-3]+"00"

l = [int(_l,2) for _l in l]
l.sort()
l = ['{0:032b}'.format(_l) for _l in l]


for idx in range(1024):
	if(idx%16==0):
		fw.write("// 0x")
		fw.write('{0:08x}'.format(idx))
		fw.write("\n")
	fw.write(l[idx])
	fw.write("\n")