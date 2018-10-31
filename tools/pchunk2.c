#include <stdio.h>
#include <stdlib.h>

int main(int argc, char **argv)
{
  char header[3];
  int val;
  FILE *in;
  FILE *out;
  char cmd[256];
  int rawmode = 0;
  if (argc < 3)
  {
    printf("Invokes exomizer2.08 (forward mode + no literal sequences + max.sequence 255 bytes), output with chunkfile header & custom shortened exomizer header. Specify \"raw\" as extra parameter to indicate the input is raw data and the resulting chunkfile should have 0 objects. Note that Exomizer 2.08 should exist in path as 'exomizer208'.\n\nUsage: pchunk2 <infile> <outfile> [raw]\n");
    return 1;
  }
  if (argc > 3 && !strcmp(argv[3], "raw"))
    rawmode = 1;

  in = fopen(argv[1], "rb");
  if (!in) return 1;
  out = fopen("temp.bin", "wb");
  if (!out) return 1;
  
  if (!rawmode)
  {
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
      
      sprintf(cmd, "exomizer208 level -M255 -c -f -o%s %s@0", "temp2.bin", "temp.bin");
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
      // Skip first 2 bytes of exomized output
      fgetc(in);
      fgetc(in);
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
  else
  {
      int datasize = 0;
      for(;;)
      {
        int c = fgetc(in);
        if (c == EOF) break;
        fputc(c, out);
      }
      fclose(in);
      fclose(out);

      sprintf(cmd, "exomizer208 level -M255 -c -f -o%s %s@0", "temp2.bin", "temp.bin");
      val = system(cmd);
      if (val > 0) return val;

      unlink("temp.bin");
      in = fopen("temp2.bin", "rb");
      if (!in) return 1;
      fseek(in, 0, SEEK_END);
      datasize = ftell(in) - 2;
      fseek(in, 0, SEEK_SET);

      out = fopen(argv[2], "wb");
      if (!out) return 1;
      fputc(datasize & 0xff, out);
      fputc(datasize >> 8, out);
      fputc(0, out);
      // Skip first 2 bytes of exomized output
      fgetc(in);
      fgetc(in);
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
}
