# change filename to desired dd_E file
with open("./dd_E.csv", 'r') as f:
	ed = f.read().splitlines()

# change filename to desired dd_V file
with open("./dd_V.csv", 'r') as f:
	vd = f.read().splitlines()

dSeq_v_list = []
dSeq_E_list = []

for i in range(len(ed)):
	for j in range(int(ed[i])):
		dSeq_E_list.append(i + 1)

for i in range(len(vd)):
	for j in range(int(vd[i])):
		dSeq_v_list.append(i + 1)

with open("./dSeq_v_list.csv", 'w') as f:
	for i in range(len(dSeq_v_list)):
		f.write(str(dSeq_v_list[i]) + "\n")

with open("./dSeq_E_list.csv", 'w') as f:
	for i in range(len(dSeq_E_list)):
		f.write(str(dSeq_E_list[i]) + "\n")

print("dSeq_v_list length:", str(len(dSeq_v_list)))
print("dSeq_E_list length:", str(len(dSeq_E_list)))
