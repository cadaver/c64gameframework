#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
  int val;
  int len;
  FILE *in;
  FILE *out;
  char cmd[256];
  if (argc < 3)
  {
    printf("Invokes exomizer3 raw mode and produces both packed and unpacked output\nUsage: packmwu <infile> <outfile>\n");
    return 1;
  }

  sprintf(cmd, "exomizer3 raw -T4 -M256 -c -o%s %s", argv[2], argv[1]);
  val = system(cmd);
  if (val > 0) return val;

  char* pak = strstr(argv[2], ".pak");
  if (pak)
  {
    memcpy(pak, ".unp", 4);
    in = fopen(argv[1], "rb");
    if (!in) return 1;
    fseek(in, 0, SEEK_END);
    len = ftell(in);
    fseek(in, 0, SEEK_SET);
    out = fopen(argv[2], "wb");
    if (!out) return 1;
    fputc(len & 0xff, out);
    fputc(len >> 8, out);
    for (;;)
    {
      int c = fgetc(in);
      if (c == EOF) break;
      fputc(c, out);
    }
    fclose(in);
    fclose(out);
  }

  return 0;
}
