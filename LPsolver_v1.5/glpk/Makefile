# Build GLPK for MMIX with GCC cross-compiler

ifndef subdir
subdir = .
endif

glpkdir = $(subdir)/glpk-4.47

glpkOBJs = \
$(glpkdir)/src/glpapi01.o \
$(glpkdir)/src/glpapi02.o \
$(glpkdir)/src/glpapi03.o \
$(glpkdir)/src/glpapi04.o \
$(glpkdir)/src/glpapi05.o \
$(glpkdir)/src/glpapi06.o \
$(glpkdir)/src/glpapi07.o \
$(glpkdir)/src/glpapi08.o \
$(glpkdir)/src/glpapi09.o \
$(glpkdir)/src/glpapi10.o \
$(glpkdir)/src/glpapi11.o \
$(glpkdir)/src/glpapi12.o \
$(glpkdir)/src/glpapi13.o \
$(glpkdir)/src/glpapi14.o \
$(glpkdir)/src/glpapi15.o \
$(glpkdir)/src/glpapi16.o \
$(glpkdir)/src/glpapi17.o \
$(glpkdir)/src/glpapi18.o \
$(glpkdir)/src/glpapi19.o \
$(glpkdir)/src/glpapi20.o \
$(glpkdir)/src/glpapi21.o \
$(glpkdir)/src/glpavl.o \
$(glpkdir)/src/glpbfd.o \
$(glpkdir)/src/glpbfx.o \
$(glpkdir)/src/glpcpx.o \
$(glpkdir)/src/glpdmp.o \
$(glpkdir)/src/glpdmx.o \
$(glpkdir)/src/glpenv01.o \
$(glpkdir)/src/glpenv02.o \
$(glpkdir)/src/glpenv03.o \
$(glpkdir)/src/glpenv04.o \
$(glpkdir)/src/glpenv05.o \
$(glpkdir)/src/glpenv06.o \
$(glpkdir)/src/glpenv07.o \
$(glpkdir)/src/glpenv08.o \
$(glpkdir)/src/glpfhv.o \
$(glpkdir)/src/glpgmp.o \
$(glpkdir)/src/glphbm.o \
$(glpkdir)/src/glpini01.o \
$(glpkdir)/src/glpini02.o \
$(glpkdir)/src/glpios01.o \
$(glpkdir)/src/glpios02.o \
$(glpkdir)/src/glpios03.o \
$(glpkdir)/src/glpios04.o \
$(glpkdir)/src/glpios05.o \
$(glpkdir)/src/glpios06.o \
$(glpkdir)/src/glpios07.o \
$(glpkdir)/src/glpios08.o \
$(glpkdir)/src/glpios09.o \
$(glpkdir)/src/glpios10.o \
$(glpkdir)/src/glpios11.o \
$(glpkdir)/src/glpios12.o \
$(glpkdir)/src/glpipm.o \
$(glpkdir)/src/glplib01.o \
$(glpkdir)/src/glplib02.o \
$(glpkdir)/src/glplib03.o \
$(glpkdir)/src/glplpf.o \
$(glpkdir)/src/glplpx01.o \
$(glpkdir)/src/glplpx02.o \
$(glpkdir)/src/glplpx03.o \
$(glpkdir)/src/glpluf.o \
$(glpkdir)/src/glplux.o \
$(glpkdir)/src/glpmat.o \
$(glpkdir)/src/glpmpl01.o \
$(glpkdir)/src/glpmpl02.o \
$(glpkdir)/src/glpmpl03.o \
$(glpkdir)/src/glpmpl04.o \
$(glpkdir)/src/glpmpl05.o \
$(glpkdir)/src/glpmpl06.o \
$(glpkdir)/src/glpmps.o \
$(glpkdir)/src/glpnet01.o \
$(glpkdir)/src/glpnet02.o \
$(glpkdir)/src/glpnet03.o \
$(glpkdir)/src/glpnet04.o \
$(glpkdir)/src/glpnet05.o \
$(glpkdir)/src/glpnet06.o \
$(glpkdir)/src/glpnet07.o \
$(glpkdir)/src/glpnet08.o \
$(glpkdir)/src/glpnet09.o \
$(glpkdir)/src/glpnpp01.o \
$(glpkdir)/src/glpnpp02.o \
$(glpkdir)/src/glpnpp03.o \
$(glpkdir)/src/glpnpp04.o \
$(glpkdir)/src/glpnpp05.o \
$(glpkdir)/src/glpnpp06.o \
$(glpkdir)/src/glpqmd.o \
$(glpkdir)/src/glprgr.o \
$(glpkdir)/src/glprng01.o \
$(glpkdir)/src/glprng02.o \
$(glpkdir)/src/glpscf.o \
$(glpkdir)/src/glpscl.o \
$(glpkdir)/src/glpsdf.o \
$(glpkdir)/src/glpspm.o \
$(glpkdir)/src/glpspx01.o \
$(glpkdir)/src/glpspx02.o \
$(glpkdir)/src/glpsql.o \
$(glpkdir)/src/glpssx01.o \
$(glpkdir)/src/glpssx02.o \
$(glpkdir)/src/glptsp.o \
$(glpkdir)/src/amd/amd_1.o \
$(glpkdir)/src/amd/amd_2.o \
$(glpkdir)/src/amd/amd_aat.o \
$(glpkdir)/src/amd/amd_control.o \
$(glpkdir)/src/amd/amd_defaults.o \
$(glpkdir)/src/amd/amd_dump.o \
$(glpkdir)/src/amd/amd_info.o \
$(glpkdir)/src/amd/amd_order.o \
$(glpkdir)/src/amd/amd_post_tree.o \
$(glpkdir)/src/amd/amd_postorder.o \
$(glpkdir)/src/amd/amd_preprocess.o \
$(glpkdir)/src/amd/amd_valid.o \
$(glpkdir)/src/minisat/minisat.o \

glpkColAmd = \
$(glpkdir)/src/colamd/colamd.o 

zlibOBJs = \
$(glpkdir)/src/zlib/adler32.o \
$(glpkdir)/src/zlib/compress.o \
$(glpkdir)/src/zlib/crc32.o \
$(glpkdir)/src/zlib/deflate.o \
$(glpkdir)/src/zlib/gzclose.o \
$(glpkdir)/src/zlib/gzlib.o \
$(glpkdir)/src/zlib/gzread.o \
$(glpkdir)/src/zlib/gzwrite.o \
$(glpkdir)/src/zlib/infback.o \
$(glpkdir)/src/zlib/inffast.o \
$(glpkdir)/src/zlib/inflate.o \
$(glpkdir)/src/zlib/inftrees.o \
$(glpkdir)/src/zlib/trees.o \
$(glpkdir)/src/zlib/uncompr.o \
$(glpkdir)/src/zlib/zio.o \
$(glpkdir)/src/zlib/zutil.o \

allGLPKObjs = $(glpkOBJs) \
	      $(glpkColAmd) \
 	      $(zlibOBJs) \
	      $(subdir)/patches_global.o \
 	      $(subdir)/glpk_log.o

GLP_COMPILE = $(CC) $(CPPFLAGS) $(CFLAGS) -I$(glpkdir)/src
	
$(glpkOBJs): 
	$(GLP_COMPILE) -Wno-parentheses -include $(subdir)/patches_glpk.h -c $(@:.o=.c) -o $@

$(glpkColAmd):
	$(GLP_COMPILE) -Wno-address -I$(glpkdir)/src -include $(subdir)/patches_colamd.h -c $(@:.o=.c) -o $@

$(zlibOBJs):
	$(GLP_COMPILE) -Wno-address -I$(glpkdir)/src -include $(subdir)/patches_zlib.h -c $(@:.o=.c) -o $@

libglpk.a: $(allGLPKObjs)
	ar  rcs $@ $^

clean_glpk:
	rm -f glpk.o
	rm -f $(glpkOBJs)

EXTRA_CLEAN=$(allGLPKObjs)
.DEFAULT_GOAL := glpk.o