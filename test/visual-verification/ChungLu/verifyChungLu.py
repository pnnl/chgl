import matplotlib.pyplot as plt
import math

with open("../../../data/output/ChungLu/condMat/ddChapelCL_E.csv", 'r') as f:
	output_ddCL_E = f.read().splitlines()

with open("../../../data/output/ChungLu/condMat/ddChapelCL_V.csv", 'r') as f:
	output_ddCL_V = f.read().splitlines()

with open("../../../data/output/ChungLu/condMat/mpdChapelCL_E.csv", 'r') as f:
	output_mpdCL_E = f.read().splitlines()

with open("../../../data/output/ChungLu/condMat/mpdChapelCL_V.csv", 'r') as f:
	output_mpdCL_V = f.read().splitlines()


with open("../../../data/condMat/dd_E.csv", 'r') as f:
	input_dd_E = f.read().splitlines()

with open("../../../data/condMat/dd_V.csv", 'r') as f:
	input_dd_V = f.read().splitlines()

with open("../../../data/condMat/mpd_E.csv", 'r') as f:
	input_mpd_E = f.read().splitlines()

with open("../../../data/condMat/mpd_V.csv", 'r') as f:
	input_mpd_V = f.read().splitlines()

input_e_x = []
input_e_y = []
input_v_x = []
input_v_y = []
output_e_x = []
output_e_y = []
output_v_x = []
output_v_y = []

for i in range(len(output_ddCL_E)):
	for j in range(len(output_ddCL_E[i])):
		output_e_x.append(i+1)
		output_e_y.append(output_mpdCL_E[i])

for i in range(len(output_ddCL_V)):
	for j in range(len(output_ddCL_V[i])):
		output_v_x.append(i+1)
		output_v_y.append(output_mpdCL_V[i])

for i in range(len(input_dd_E)):
	for j in range(len(input_dd_E[i])):
		input_e_x.append(i+1)
		input_e_y.append(input_mpd_E[i])

for i in range(len(input_dd_V)):
	for j in range(len(input_dd_V[i])):
		input_v_x.append(i+1)
		input_v_y.append(input_mpd_V[i])

plt.loglog(output_e_x, output_e_y, marker = 'o', linestyle = '--', color = 'r', label='Output E')
plt.loglog(output_v_x, output_v_y, marker = 'o', linestyle = '--', color='b', label='Output V')
plt.loglog(input_e_x, input_e_y, marker = 'o', linestyle = '--', color='g', label='Input E')
plt.loglog(input_v_x, input_v_x, marker = 'o', linestyle = '--', color='black', label='Input V')

plt.xlabel('Degree')
plt.ylabel('PDMC')
plt.title('Chung Lu Visual Verification')
plt.legend()
plt.show()
