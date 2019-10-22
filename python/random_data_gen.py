from random import randint
import sys
f = open("test_data/data.in", "w")
MAX=2**32-1
a=[format(randint(0,MAX),'b') for _ in range(1024)]

for idx in range(1024):
	f.write(a[idx])
	f.write("\n")

