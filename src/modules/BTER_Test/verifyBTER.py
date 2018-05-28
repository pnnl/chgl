import matplotlib.pyplot as plt
import math

BTER_Node_Frequency = {}
Node_Frequency = {}
BTER_dseq_E_list = []
dseq_E_list = []

# Previously generated BTER data for comparison
with open("./ddBTER_E.csv", 'r') as f:
	BTER_Node_Degrees = f.read().splitlines()

# Change filename to be desired file
with open("./GENERATED_dseq_E_list.csv", 'r') as f:
	Node_Degrees = f.read().splitlines()

# processing BTER dseq_E_list
for i in range(len(BTER_Node_Degrees)):
	BTER_Node_Degrees[i] = int(BTER_Node_Degrees[i])

	for j in range(BTER_Node_Degrees[i]):
		BTER_dseq_E_list.append(i + 1)


for i in range(len(BTER_dseq_E_list)):
	if BTER_dseq_E_list[i] in BTER_Node_Frequency.keys():
		BTER_Node_Frequency[BTER_dseq_E_list[i]] += 1
	else:
		BTER_Node_Frequency[BTER_dseq_E_list[i]] = 1

for i in range(len(Node_Degrees)):
	Node_Degrees[i] = int(Node_Degrees[i])
	if Node_Degrees[i] in Node_Frequency.keys():
		Node_Frequency[Node_Degrees[i]] += 1
	else:
		Node_Frequency[Node_Degrees[i]] = 1

BTER_X = []
BTER_Y = []
X = []
Y = []

for key, value in sorted(BTER_Node_Frequency.items()):
	if key != 0:
		BTER_X.append(math.log(key))
	else:
		BTER_X.append(0)

	BTER_Y.append(math.log(value))

for key, value in sorted(Node_Frequency.items()):
	if key != 0:
		X.append(math.log(key))
	else:
		X.append(0)

	Y.append(math.log(value))

#plt.xlim(min(X), max(X))
#plt.ylim(min(Y), max(Y))
plt.plot(X, Y, marker = 'o', linestyle = '--', color = 'r', label='Generated')
plt.plot(BTER_X, BTER_Y, marker = 'o', linestyle = '--', color='b', label='Good BTER')
plt.xlabel('log(Node DD)')
plt.ylabel('log(Frequency)')
plt.title('compare')
plt.legend()
plt.show()
