import numpy 
import glob
import matplotlib.pyplot as plt 

def find_best_fit(N, r):
	R = 1
	C = 1
	while R*C < N:
		if C/R < r: C += 1
		else:       R += 1
	return (R, C)


files = glob.glob("series_*.txt")


R, C = find_best_fit(len(files), 16/9)
fig1, axes1 = plt.subplots(R, C, figsize=(16,9))
fig1.subplots_adjust(hspace=0.3, wspace=0.3)
fig2, axes2 = plt.subplots(R, C, figsize=(16,9))
fig2.subplots_adjust(hspace=0.3, wspace=0.3)

for i in range(len(files)):
	x = i % C
	y = i // C
	filename = files[i]
	name = filename[len("series_"):len(filename)-len(".txt")]

	timestep, time, memory = numpy.loadtxt(files[i], unpack=True)
	bandwidth = memory / time 
	
	if len(files) == 1: ax1 = axes1
	elif R == 1: ax1 = axes1[x]
	else:      ax1 = axes1[y, x]

	if len(files) == 1: ax2 = axes2
	elif R == 1: ax2 = axes2[x]
	else:      ax2 = axes2[y, x]

	ax1.plot(timestep, time*1.0e3, '.', label=name)
	ax1.set_ylabel("execution time (ms)")
	ax1.set_xlabel("simulation time (step)")
	ax1.set_title(name)

	ax2.plot(timestep, bandwidth*1.0e-9, '.', label=name)
	ax2.set_ylabel("effective bandwidth (GB/s)")
	ax2.set_xlabel("simulation time (step)")
	ax2.set_title(name)


fig3, ax3 = plt.subplots(1, 1, figsize=(16,9))
fig4, ax4 = plt.subplots(1, 1, figsize=(16,9))

max_bw = 0.0
for i in range(len(files)):
	x = i % C
	y = i // C
	filename = files[i]
	name = filename[len("series_"):len(filename)-len(".txt")]

	timestep, time, memory = numpy.loadtxt(files[i], unpack=True)
	bandwidth = memory / time 
	
	ax3.plot(timestep, time*1.0e3, '.', label=name)
	ax3.set_ylabel("execution time (ms)")
	ax3.set_xlabel("simulation time (step)")

	ax4.plot(timestep, bandwidth*1.0e-9, '.', label=name)
	ax4.set_ylabel("effective bandwidth (GB/s)")
	ax4.set_xlabel("simulation time (step)")

	max_bw = max(max_bw, min(2000, numpy.max(bandwidth*1.0e-9)))

ax4.set_ylim([0, max_bw*1.05])

ax3.grid()
ax3.legend()
ax4.legend()

plt.show()