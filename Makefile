all: example.d64 exampleef.crt examplegmod2.crt

clean:
	del *.prg
	del *.pak
	del *.tbl
	del *sym.s
	del *.d64
	del *.crt

example.d64: example.seq boot.prg loader.prg main.pak music00.pak level00.pak charset00.pak sprplayer.pak sprcommon.pak sprenemy.pak script00.pak
	maked64 example.d64 example.seq EXAMPLE_GAME______EG_2A 10

exampleef.crt: example.d64 example.seq main.pak loadsym.s mainsymcart.s efboot.s
	dasm efboot.s -oefboot.bin -f3
	makeef efboot.bin examplecart.seq exampleef.bin
	cartconv -p -i exampleef.bin -o exampleef.crt -t easy

examplegmod2.crt: example.d64 example.seq main.pak loadsym.s mainsymcart.s gmod2boot.s
	dasm gmod2boot.s -ogmod2boot.bin -f3
	makegmod2 gmod2boot.bin examplecart.seq examplegmod2-flash.bin examplegmod2-eeprom.bin
	cartconv -p -i examplegmod2-flash.bin -o examplegmod2.crt -t gmod2

loader.prg: exomizer.s loader.s kernal.s memory.s
	dasm ldepack.s -oloader.prg -f3 -sldepack.tbl
	symbols ldepack.tbl ldepacksym.s ldepacksym.txt
	dasm loader.s -oloader.bin -f3 -sloader.tbl
	symbols loader.tbl loadsym.s loadsym.txt
	pack3 loader.bin loader.pak
	dasm ldepack.s -oloader.prg -f3 -sldepack.tbl

boot.prg: boot.s kernal.s loader.prg
	dasm boot.s -oboot.prg

main.pak: loader.prg memory.s defines.s main.s init.s input.s file.s screen.s raster.s math.s sound.s \
	panel.s actor.s sprite.s physics.s level.s ai.s \
	actordata.s sounddata.s aligneddata.s playroutinedata.s \
	bg/worldinfo.s bg/scorescr.chr
	dasm main.s -omain.bin -smain.tbl -f3
	symbols main.tbl mainsym.s
	symbols main.tbl mainsymcart.s mainsymcart.txt
	pack3 main.bin main.pak

music00.pak: music/example.sng
	gt2mini music/example.sng music00.s -ed000
	dasm music00.s -omusic00.prg -p3
	exomizer3 level -M256 -f -c -omusic00.pak music00.prg

level00.pak: bg/world00.map bg/world00.lvo bg/world00.lva
	pchunk3 bg/world00.map level00map.pak
	filejoin bg/world00.lvo+bg/world00.lva level00data.bin
	pack3 level00data.bin level00data.pak
	filejoin level00map.pak+level00data.pak level00.pak

charset00.pak: charset00.s mainsym.s memory.s bg/world00.blk bg/world00.bli bg/world00.chr bg/world00.oba
	dasm charset00.s -ocharset00.bin -f3
	pack3 charset00.bin charset00.pak

sprcommon.pak: spr/common.spr.res
	pchunk3 spr/common.spr.res sprcommon.pak

sprplayer.pak: spr/player.spr.res
	pchunk3 spr/player.spr.res sprplayer.pak

sprenemy.pak: spr/enemy.spr.res
	pchunk3 spr/enemy.spr.res sprenemy.pak

script00.pak: script00.s mainsym.s macros.s memory.s
	dasm script00.s -oscript00.bin -f3
	pchunk3 script00.bin script00.pak