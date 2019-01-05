#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
  char header[3];
  int val;
  FILE *in;
  FILE *out;
  char cmd[256];
  if (argc < 3)
  {
    printf("Invokes exomizer3, output with chunkfile header\nUsage: pchunkmwu <infile> <outfile>\n");
    return 1;
  }
  in = fopen(argv[1], "rb");
  if (!in) return 1;
  out = fopen("temp.bin", "wb");
  if (!out) return 1;
  header[0] = fgetc(in);
  header[1] = fgetc(in);
  header[2] = fgetc(in);
  for(;;)
  {
    int c = fgetc(in);
    if (c == EOF) break;
    fputc(c, out);
  }
  fclose(in);
  fclose(out);
  
  sprintf(cmd, "exomizer3 raw -M256 -c -o%s %s", "temp2.bin", "temp.bin");
  val = system(cmd);
  if (val > 0) return val;

  unlink("temp.bin");
  in = fopen("temp2.bin", "rb");
  if (!in) return 1;
  out = fopen(argv[2], "wb");
  if (!out) return 1;
  fputc(header[0], out);
  fputc(header[1], out);
  fputc(header[2], out);
  for(;;)
  {
    int c = fgetc(in);
    if (c == EOF) break;
    fputc(c, out);
  }
  fclose(in);
  fclose(out);
  unlink("temp2.bin");
  return val;
}
