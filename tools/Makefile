all: worlded3.exe spred3.exe gt2mini.exe usecount.exe makeef.exe makegmod2.exe pack3.exe pchunk3.exe maked64.exe symbols.exe filejoin.exe filesplit.exe bmeconv.exe datafile.exe dat2inc.exe gfxconv.exe

clean:
	del *.exe
	del *.spr
	del editor.pal
	del editor.dat
	del editdata.c

editor.dat: bmeconv.exe datafile.exe editor.lbm editfont.lbm
	bmeconv -s -t255 -r254 -h253 editor.lbm editor.spr
	bmeconv -s -t255 -r254 -h253 editfont.lbm editfont.spr
	bmeconv -p editor.lbm editor.pal
	datafile editor.dat filelist.txt

editdata.c: dat2inc.exe editor.dat
	dat2inc editor.dat editdata.c

worlded3.exe: worlded3.cpp editdata.c stb_image_write.c
	g++ worlded3.cpp editdata.c stb_image_write.c bme.c bme_gfx.c bme_io.c bme_win.c bme_kbd.c bme_mou.c -oworlded3.exe -fpermissive -w -march=i386 -static-libstdc++ -static-libgcc -lmingw32 -lSDLmain -lSDL -Wl,-Bstatic -lstdc++ -lpthread -Wl,-Bdynamic
	strip worlded3.exe

spred3.exe: spred3.cpp fileio.c editdata.c
	g++ spred3.cpp fileio.c editdata.c bme.c bme_gfx.c bme_io.c bme_win.c bme_kbd.c bme_mou.c  -ospred3.exe -fpermissive -w -march=i386 -static-libstdc++ -static-libgcc -lmingw32 -lSDLmain -lSDL -Wl,-Bstatic -lstdc++ -lpthread -Wl,-Bdynamic
	strip spred3.exe

gt2mini.exe: gt2mini.c fileio.c
	gcc gt2mini.c fileio.c -ogt2mini.exe

usecount.exe: usecount.cpp
	g++ usecount.cpp -ousecount.exe -w -march=i386 -static-libstdc++ -static-libgcc -lmingw32 -Wl,-Bstatic -lstdc++ -lpthread -Wl,-Bdynamic
	strip usecount.exe

makeef.exe: makeef.cpp
	g++ makeef.cpp -omakeef.exe -w -march=i386 -static-libstdc++ -static-libgcc -lmingw32 -Wl,-Bstatic -lstdc++ -lpthread -Wl,-Bdynamic
	strip makeef.exe

makegmod2.exe: makegmod2.cpp
	g++ makegmod2.cpp -omakegmod2.exe -w -march=i386 -static-libstdc++ -static-libgcc -lmingw32 -Wl,-Bstatic -lstdc++ -lpthread -Wl,-Bdynamic
	strip makegmod2.exe

pack3.exe: pack3.c
	gcc pack3.c -opack3.exe

pchunk3.exe: pchunk3.c
	gcc pchunk3.c -opchunk3.exe

maked64.exe: maked64.c
	gcc maked64.c -omaked64.exe

symbols.exe: symbols.c
	gcc symbols.c -osymbols.exe

bmeconv.exe: bmeconv.c fileio.c
	gcc bmeconv.c fileio.c -obmeconv.exe

datafile.exe: datafile.c fileio.c
	gcc datafile.c fileio.c -odatafile.exe

dat2inc.exe: dat2inc.c
	gcc dat2inc.c -odat2inc.exe

gfxconv.exe: gfxconv.c fileio.c
	gcc gfxconv.c fileio.c -ogfxconv.exe

filejoin.exe: filejoin.c
	gcc filejoin.c -ofilejoin.exe

filesplit.exe: filesplit.c
	gcc filesplit.c -ofilesplit.exe
