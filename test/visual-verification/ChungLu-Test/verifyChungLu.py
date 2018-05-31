import matplotlib.pyplot as plt
import math

with open("./OUTPUT_dseq_E_List.csv", 'r') as f:
	output_dseq_E_List = f.read().splitlines()

with open("./OUTPUT_dseq_V_List.csv", 'r') as f:
	output_dseq_V_List = f.read().splitlines()

with open("./INPUT_dseq_E_List.csv", 'r') as f:
	input_dseq_E_List = f.read().splitlines()

with open("./INPUT_dseq_V_List.csv", 'r') as f:
	input_dseq_V_List = f.read().splitlines()

output_dseq_E_Frequency = {}
output_dseq_V_Frequency = {}
input_dseq_E_Frequency = {}
input_dseq_V_Frequency = {}


for i in range(len(output_dseq_E_List)):
	if output_dseq_E_List[i] in output_dseq_E_Frequency.keys():
		output_dseq_E_Frequency[output_dseq_E_List[i]] += 1
	else:
		output_dseq_E_Frequency[output_dseq_E_List[i]] = 1

for i in range(len(output_dseq_V_List)):
	if output_dseq_V_List[i] in output_dseq_V_Frequency.keys():
		output_dseq_V_Frequency[output_dseq_V_List[i]] += 1
	else:
		output_dseq_V_Frequency[output_dseq_V_List[i]] = 1

for i in range(len(input_dseq_E_List)):
	if input_dseq_E_List[i] in input_dseq_E_Frequency.keys():
		input_dseq_E_Frequency[input_dseq_E_List[i]] += 1
	else:
		input_dseq_E_Frequency[input_dseq_E_List[i]] = 1

for i in range(len(input_dseq_V_List)):
	if input_dseq_V_List[i] in input_dseq_V_Frequency.keys():
		input_dseq_V_Frequency[input_dseq_V_List[i]] += 1
	else:
		input_dseq_V_Frequency[input_dseq_V_List[i]] = 1

input_V_x = []
input_V_y = []
input_E_x = []
input_E_y = []
output_V_x = []
output_V_y = []
output_E_x = []
output_E_y = []

for key, value in sorted(input_dseq_V_Frequency.items()):
	if key != 0:
		input_V_x.append(math.log(key))
	else:
		input_V_x.append(0)

	input_V_y.append(math.log(value))

for key, value in sorted(input_dseq_E_Frequency.items()):
	if key != 0:
		input_E_x.append(math.log(key))
	else:
		input_E_x.append(0)

	input_E_y.append(math.log(value))

for key, value in sorted(output_dseq_V_Frequency.items()):
	if key != 0:
		output_V_x.append(math.log(key))
	else:
		output_V_x.append(0)

	output_V_y.append(math.log(value))

for key, value in sorted(output_dseq_E_Frequency.items()):
	if key != 0:
		output_E_x.append(math.log(key))
	else:
		output_E_x.append(0)

	output_E_y.append(math.log(value))

#plt.xlim(min(X), max(X))
#plt.ylim(min(Y), max(Y))
plt.plot(input_V_x, input_V_y, marker = 'o', linestyle = '--', color = 'r', label='Input V Degree')
plt.plot(output_V_x, output_V_y, marker = 'o', linestyle = '--', color='b', label='Output V Degree')
plt.plot(input_E_x, input_E_y, marker = 'o', linestyle = '--', color='r', label='Input E Degree')
plt.plot(output_E_x, output_E_y, marker = 'o', linestyle = '--', color='b', label='Output E Degree')
plt.xlabel('log(Degree)')
plt.ylabel('log(Frequency)')
plt.title('compare')
plt.legend()
plt.show()
