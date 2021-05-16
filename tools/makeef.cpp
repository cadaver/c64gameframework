#include <stdio.h>
#include <stdlib.h>
#include <memory.h>

#define MAXFILES 0x100
#define FIRSTSAVEFILE 0xf0

unsigned char* cart = new unsigned char[0x100000];
unsigned char* usedsectors = new unsigned char[0x1000];
int bootcodesize = 8192;
int maxsize = 0;
int savestartoffset = 0;
int savefiles = 4;

int getfreeoffset(int filesize)
{
    int startsec = 0;

    int sectors = (filesize+0xff) / 0x100;

    for (int i = startsec; i < 0x1000; ++i)
    {
        for (int j = i; j < 0x1000; ++j)
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
    cart[0x0000+filenum] = ((startoffset >> 8) & 0x3f) + 0x80; // Startoffset within bank
    cart[0x0100+filenum] = (startoffset >> 14); // Bank
    cart[0x0200+filenum] = filesize & 0xff;
    cart[0x0300+filenum] = filesize >> 8;
    // If filesize lowbyte 0, must predecrement high size
    if (!(filesize & 0xff))
        --cart[0x300+filenum];

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
    if (maxsize < fileend)
    {
        maxsize = fileend;
        maxsize = (maxsize+0x1ffff) & 0xfffe0000;
    }
}

int main(int argc, char **argv)
{
    if (argc < 2)
    {
        printf("Usage: makeef <bootcode> <seqfile> <output> [numsavefiles]\n"
            "Builds easyflash bin cartridge from bootcode (16KB) and sequencefile.\nEach savefile allocates 64KB from the cart, by default there's room for 4.");
        return 1;
    }
    
    if (argc > 4)
    {
        sscanf(argv[4], "%d", &savefiles);
        ++savefiles;
        savefiles &= 0xfe;
    }

    memset(cart, 0xff, 0x100000);
    memset(usedsectors, 0, 0x1000);
    // Mark the "directory" used
    for (int i = 0x00; i < 0x04; ++i)
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
    insertfile(0xff, 0x4000-bootcodesize, bootcodedata, bootcodesize, true);
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

    savestartoffset = (maxsize + 0x1ffff) & 0xfffe0000;
    cart[0x03ff] = (savestartoffset >> 14); // Save start bank
    for (int i = 0; i < savefiles/2; ++i)
    {
        cart[savestartoffset + i * 0x20000 + 0] = 0; // Mark save directory itself invalid in directory to invalid to force EasyProg to erase the save bank on writing
        cart[savestartoffset + i * 0x20000 + 1] = 0; // Even files in low bank
        cart[savestartoffset + i * 0x20000 + 0x2000] = 0;
        cart[savestartoffset + i * 0x20000 + 0x2001] = 0; // Odd files in high bank
    }

    maxsize += savefiles * 0x10000;
    if (maxsize > 0x100000)
    {
        printf("Cart too large\n");
        return 1;
    }

    FILE* out = fopen(argv[3], "wb");
    if (!out)
    {
        printf("Could not open outfile\n");
        return 1;
    }
    fwrite(cart, 0x100000, 1, out);
    fclose(out);
    printf("Cart image written, %d bytes\n", maxsize);
    return 0;
}