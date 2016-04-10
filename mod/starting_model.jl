# This program generates a 3D synthetic seismic section by convolution with
# a the Ricker wavelet defined in Seismic.jl's ShotProfileWEM. To do this
# it reads a velocity model in, calculates reflection coeficients, and uses
# a 1D convolution per trace in the frequency domain.
#
# by GRAM | 8 Apr 2016

using Seismic

# import vel model
vel,vel_h = SeisRead("../vel/vel_1")
nz = size(vel)[1]
nx = size(vel)[2]
ny = size(vel)[3]

# initialize
peakF = 80    # Ricker peak freq
samp  = .001 # Ricker sample rate
dz = 10
dx = 20
dy = 20

temp = ricker(peakF, samp)
rick = zeros(Float32, size(temp)[1])
for i = 1 : size(temp)[1]
	rick[i] = convert(Float32, temp[i])
end

print("\nThis Ricker wavelet is ",size(rick)[1]," samples long.\n")

r = zeros(Float32,nz,nx,ny)

# calculate (normal incidence) reflection coeficients
d1 = d2 = 1 # acoustic assumption

for k = 1 : ny
	for j = 1 : nx
		for i = 1 : nz - 1
			r[i,j,k] = ((d2 * vel[i+1,j,k] - d1 * vel[i,j,k]) /
				   (d2 * vel[i+1,j,k] + d1 * vel[i,j,k])) ^ 2
		end
	end
end

# write out reflection coefficients
h = Array(Header,nx*ny)
ex = Seismic.Extent(convert(Int32,nz), convert(Int32,nx), convert(Int32,ny), 
	1, 1, 0, 0, 0, 0, 0, convert(Float32,dz), convert(Float32,dx), 
	convert(Float32,dy), 1, 1, "Depth", "mx", "my", "", "", "", "", "", 
	"", "", "")

for i = 1 : ny
	for j = 1 : nx
		h[j + nx * (i - 1)] = Seismic.InitSeisHeader()
		h[j + nx * (i - 1)].tracenum = convert(Int32, j + nx * (i - 1))
		h[j + nx * (i - 1)].o1 = convert(Float32, 0)		
		h[j + nx * (i - 1)].n1 = convert(Int32, nz)
		h[j + nx * (i - 1)].d1 = convert(Float32, dz)
		h[j + nx * (i - 1)].mx = convert(Float32, j)
		h[j + nx * (i - 1)].my = convert(Float32, i)
	end
end

SeisWrite("refl",r,vel_h,ex)

# convolve RC with Ricker wavelet to generate 0 offset section
nz_new = size(ricker)[1] + nz - 1
m = zeros(Float32, nz_new, nx, ny)
for j = 1 : ny
	for i = 1 : nx
		m[:,i,j] = conv(r[:,i,j], rick)
	end
end

# window out middle samples of convolution for physical reality
if isodd(size(m)[1]) == true
	for j = 1 : ny
		for i = 1 : nx
			vel[:,i,j] = m[(size(m)[1] - nz) / 2 : (size(m)[1] - nz) / 2, i, j]
		end
	end
else
	for j = 1 : ny
		for i = 1 : nx
			vel[:,i,j] = m[, i, j]
		end
	end
end

# write out the wavefield
h = Array(Header,nx*ny)
ex = Seismic.Extent(convert(Int32,nz), convert(Int32,nx), convert(Int32,ny), 
	1, 1, 0, 0, 0, 0, 0, convert(Float32,dz), convert(Float32,dx), 
	convert(Float32,dy), 1, 1, "Depth", "mx", "my", "", "", "", "", "", 
	"", "", "")

SeisWrite("image",m,vel_h,ex)






