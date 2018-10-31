#include <dirent.h>
#include <stdio.h>
#include <vector>
#include <map>
#include <string>
#include <algorithm>

struct Symbol
{
    std::string name;
    int address;
    int count = 0;
};

bool comparesymbol(const Symbol& lhs, const Symbol& rhs)
{
    return lhs.count > rhs.count;
}

int main(int argc, char **argv)
{
    if (argc < 2)
    {
        printf("Usage: usecount <symbolfile>\n"
            "Scans the current directory for .s files and shows sorted use count for symbols\n");
        return 1;
    }

    FILE* in = fopen(argv[1], "rt");
    if (!in)
    {
        printf("Error opening symbol file\n");
        return 1;
    }

    char buffer[80];
    std::vector<Symbol> symbols;
    std::map<std::string, bool> codeLabels;

    printf("Reading symbols\n");
    while (fgets(buffer, 80, in))
    {
        Symbol newsymbol;
        char name[80];
        sscanf(buffer, "%s %x", &name[0], &newsymbol.address);
        newsymbol.name = name;

        if (newsymbol.name == "---")
            continue; // Newer DASM symbol file title, skip

        for (int c = 0; c < newsymbol.name.length(); c++)
        {
            if (newsymbol.name[c] == '.')
                continue; // Don't dump macro labels
        }

        // In Hessian / Steel Ranger code labels begin with uppercase; these can be ignored
        if (isupper(newsymbol.name[0]))
            codeLabels[newsymbol.name] = false;
        else
            symbols.push_back(newsymbol);
    }
    fclose(in);

    std::vector<std::string> filenames;
    DIR* dir = opendir(".");
    if (dir)
    {
        struct dirent *ent;
        while (ent = readdir(dir))
        {
            std::string name = ent->d_name;
            if (name.find(".s") != std::string::npos)
                filenames.push_back(name);
        }
        closedir(dir);
    }

    for (int c = 0; c < filenames.size(); ++c)
    {
        if (filenames[c] == argv[1])
            continue; // Skip the symbol file itself
        FILE* in = fopen(filenames[c].c_str(), "rt");
        if (in)
        {
            printf("Examining file %s\n", filenames[c].c_str());

            while (fgets(buffer, 80, in))
            {
                std::string line(buffer);
                for (int d = 0; d < symbols.size(); ++d)
                {
                    int pos = line.find(symbols[d].name);
                    int endpos = pos + symbols[d].name.length();
                    if (pos != 0 && pos != std::string::npos && line[pos-1] == ' ' && (endpos == line.length() || (!isalpha(line[endpos]) && !isdigit(line[endpos]))))
                    {
                        ++symbols[d].count;
                        break;
                    }
                }
                for (std::map<std::string, bool>::iterator i = codeLabels.begin(); i != codeLabels.end(); ++i)
                {
                    int pos = line.find(i->first);
                    if (pos != 0 && pos != std::string::npos)
                        i->second = true;
                }
            }
            fclose(in);
        }
    }

    std::sort(symbols.begin(), symbols.end(), comparesymbol);
    for (int c = 0; c < symbols.size(); ++c)
        printf("Symbol %s uses %d\n", symbols[c].name.c_str(), symbols[c].count);
    for (std::map<std::string, bool>::const_iterator i = codeLabels.begin(); i != codeLabels.end(); ++i)
    {
        if (!i->second)
            printf("Unused code symbol %s\n", i->first.c_str());
    }

    return 0;
}