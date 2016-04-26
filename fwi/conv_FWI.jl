# This is the simplest example of full waveform inversion. It is
# built in the poststack domain using a simple convolution, which 
# highlights the theory of FWI, but is useless commercially.
#
# Because this is a tutorial I've written the code for clarity, not
# speed. So if you try to use some huge velocity model, it'll take
# a ton of memory and crash. Probably.
#
# by GRAM | 23 Apr 2016

using Seismic

# read initial vel model, seismic image, and Ricker wavelet
vel,vel_h = SeisRead("../vel/vel_1")
sei, sei_h = SeisRead("../vel/vel_1")
rick, rick_h = SeisRead("../mod/wav")

# initialize
nz = size(vel)[1]
nx = size(vel)[2]
ny = size(vel)[3]
dz = vel_h[1].d1
dx = vel_h[1].d2
dy = vel_h[1].d3
inc = .10		# velocity update percentage
d1 = d2 = 1		# acoustic assumption

#### main FWI loop ########################
for i = 1 : ny, j = 1 : nx, k = 1 : nz
	
	print("\n Now updating trace x = ", j, ", y = ", i, " \n")

	# build perturbed velocity models
	v_p = vel[:,j,i]
	v_p[k] += v_p[k] * (1 + inc)
	
	v_n = vel[:,j,i]
	v_n[k] += v_n[k] * (1 - inc)
	
	v_o = vel[:,j,i]

	# calculate reflection coeficients
	for kk = 1 : nz

		r_p[kk] = ((d2 * v_p[kk + 1] - d1 * v_p[kk]) /
				   (d2 * v_p[kk + 1] + d1 * v_p[kk])) ^ 2
		
		r_n[kk] = ((d2 * v_n[kk + 1] - d1 * v_n[kk]) /
				   (d2 * v_n[kk + 1] + d1 * v_n[kk])) ^ 2

		r_o[kk] = ((d2 * v_o[kk + 1] - d1 * v_o[kk]) /
				   (d2 * v_o[kk + 1] + d1 * v_o[kk])) ^ 2

	end

	# model perturbed seismic data
		# increase trace length for convolved samples
	nz_new = size(rick)[1] + nz - 1

	m_p = zeros(Float32, nz_new, nx, ny)
	m_n = zeros(Float32, nz_new, nx, ny)
	m_o = zeros(Float32, nz_new, nx, ny)

		# model seismic with a convolution
	m_p = conv(r_p, rick)
	m_n = conv(r_n, rick)
	m_o = conv(r_o, rick)

	# clip off unused (non-physical) ends of convolution
	extra = size(m_p)[1] - nz

	if isodd(extra) == true
		s_p = m_p[ceil(extra / 2) : nz - 1 + ceil(extra / 2)]
		s_n = m_n[ceil(extra / 2) : nz - 1 + ceil(extra / 2)]
		s_o = m_o[ceil(extra / 2) : nz - 1 + ceil(extra / 2)]
	else
		s_p = m_p[extra / 2 : nz - 1 + extra / 2]
		s_n = m_n[extra / 2 : nz - 1 + extra / 2]
		s_o = m_o[extra / 2 : nz - 1 + extra / 2]
	end

	# compare images
		# correlate signals
	cor_p = ifft(conj(fft(s_p))*fft(sei[:,j,i]))
	cor_n = ifft(conj(fft(s_n))*fft(sei[:,j,i]))
	cor_o = ifft(conj(fft(s_o))*fft(sei[:,j,i]))
	acor = ifft(conj(fft(sei[:,j,i]))*fft(sei[:,j,i]))

		# difference and weight
	dif_p = acor - cor_p
	dif_n = acor - cor_n
	dif_o = acor - cor_o
	
		# sum the difference vectors
	comp = [sum(dif_p),sum(dif_n),sum(dif_o)]
	
	# move in the direction of improvement
	dir = find(comp .== min(comp[1],comp[2],comp[3]))
	
	if dir == 1
		vel[k,j,i] = v_p[k]
	elseif dir == 2
		vel[k,j,i] = v_n[k]
	end
	
end

# write out the wavefield
ex = Seismic.Extent(convert(Int32,nz), convert(Int32,nx), convert(Int32,ny), 
	1, 1, 0, 0, 0, 0, 0, convert(Float32,dz), convert(Float32,dx), 
	convert(Float32,dy), 1, 1, "Depth", "mx", "my", "", "", "", "", "", 
	"", "", "")

SeisWrite("updated_vel",vel,vel_h,ex)







