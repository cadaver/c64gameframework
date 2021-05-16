#include <stdio.h>
#include <stdlib.h>
#include <memory.h>

#define MAXFILES 0x100
#define FIRSTSAVEFILE 0xf0

unsigned char* cart = new unsigned char[0x80000];
unsigned char* usedsectors = new unsigned char[0x800];
int bootcodesize = 8192-MAXFILES*4;
int maxsize = 0x80000;

int getfreeoffset(int filesize)
{
    int startsec = 0;

    int sectors = (filesize+0xff) / 0x100;

    for (int i = startsec; i < 0x800; ++i)
    {
        for (int j = i; j < 0x800; ++j)
        {
            if (usedsectors[j])
            {
                i = j;
                break;
            }
            if (j - i == sectors-1)
                return i * 0x100;
        }
    }
    return -1;
}

void insertfile(unsigned char filenum, int startoffset, unsigned char* data, int filesize, bool leaveholes = false)
{
    if (filenum < FIRSTSAVEFILE)
    {
        cart[0x1c00+filenum] = ((startoffset >> 8) & 0x1f) + 0x80; // Startoffset within bank
        cart[0x1d00+filenum] = (startoffset >> 13); // Bank
        cart[0x1e00+filenum] = filesize & 0xff;
        cart[0x1f00+filenum] = filesize >> 8;
        // If filesize lowbyte 0, must predecrement highbyte
        if (!(filesize & 0xff))
            --cart[0x1f00+filenum];
    }
    memcpy(&cart[startoffset], data, filesize);
    int sectors = (filesize+0xff) >> 8;
    int startsec = startoffset >> 8;
    for (int i = startsec; i < sectors + startsec; ++i)
    {
        if (!leaveholes)
            usedsectors[i] = 1;
        else
        {
            // For the bootcode, we can leave holes in the allocation to fill it with data files later
            for (int j = 0; j < 256; ++j)
            {
                if (cart[i*256+j] != 0xff)
                {
                    usedsectors[i] = 1;
                    break;
                }
            }
        }
    }
    int fileend = startoffset+filesize;
}

int main(int argc, char **argv)
{
    if (argc < 4)
    {
        printf("Usage: makegmod2 <bootcode> <seqfile> <output> <eeprom>\n"
            "Builds gmod2 bin cartridge from bootcode (8KB) and sequencefile.");
        return 1;
    }

    memset(cart, 0xff, 0x80000);
    memset(usedsectors, 0, 0x800);
    // Mark the "directory" used
    for (int i = 0x1c; i < 0x20; ++i)
        usedsectors[i] = 1;

    printf("Reading bootcode\n");
    FILE* bootcode = fopen(argv[1], "rb");
    if (!bootcode)
    {
        printf("Could not open bootcode\n");
        return 1;
    }
    unsigned char* bootcodedata = new unsigned char[bootcodesize];
    memset(bootcodedata, 0xff, bootcodesize);
    fread(bootcodedata, bootcodesize, 1, bootcode);
    fclose(bootcode);

    printf("Inserting bootcode\n");
    insertfile(0xff, 0, bootcodedata, bootcodesize, true);
    delete[] bootcodedata;

    FILE* seqfile = fopen(argv[2], "rb");
    if (!seqfile)
    {
        printf("Could not open sequence file\n");
        return 1;
    }

    printf("Reading seqfile & inserting files\n");
    char commandbuf[80];
    while(fgets(commandbuf, 80, seqfile))
    {
        char c64name[80];
        char dosname[80];
        int ret;

        ret = sscanf(commandbuf, "%s %s", &dosname[0], &c64name[0]);
        if (ret < 2)
            continue;
        if (dosname[0] == ';')
            continue;

        FILE *src;
        src = fopen((const char*)dosname, "rb");
        if (!src)
        {
            printf("Could not open input file %s\n", dosname);
            return 1;
        }

        int filenum = strtol((const char*)c64name, 0, 16);
        fseek(src, 0, SEEK_END);
        int filesize = ftell(src);
        fseek(src, 0, SEEK_SET);
        if (filesize > 0 && filenum < FIRSTSAVEFILE)
        {
            unsigned char* filedata = new unsigned char[filesize];
            fread(filedata, filesize, 1, src);
            fclose(src);
            int fileoffset = getfreeoffset(filesize);
            if (fileoffset < 0)
            {
                printf("Cart full\n");
                return 1;
            }
            printf("File name %s number %d inserting to %d\n", dosname, filenum, fileoffset);
            insertfile(filenum, fileoffset, filedata, filesize);
            delete[] filedata;
        }
        else
            fclose(src);
    }

    FILE* out = fopen(argv[3], "wb");
    if (!out)
    {
        printf("Could not open outfile\n");
        return 1;
    }
    fwrite(cart, maxsize, 1, out);
    fclose(out);
    
    unsigned char eeprom[2048];
    memset(eeprom, 0, sizeof eeprom);
    out = fopen(argv[4], "wb");
    if (!out)
    {
        printf("Could not open outfile\n");
        return 1;
    }
    fwrite(eeprom, 2048, 1, out);
    fclose(out);

    printf("Cart image written, %d bytes\n", maxsize);
    return 0;
}