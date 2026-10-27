/* CVE-2023-50472 reproduction using a disposable JSON document. */
#include <stdio.h>
#include <string.h>
#include "cJSON.h"

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

int main(int argc, char **argv)
{
    const char *input;
    cJSON *config;
    cJSON *setting;
    char *updated;
    int missing;

#ifdef _WIN32
    /* Let the deliberate lab crash terminate without a modal error dialog. */
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
#endif
    /* Preserve output even if the vulnerable library crashes next. */
    setvbuf(stdout, NULL, _IONBF, 0);
    printf("cJSON version: %s\n", cJSON_Version());

    if (argc == 2 && strcmp(argv[1], "--version") == 0)
        return 0;
    if (argc > 2 || (argc == 2 && strcmp(argv[1], "--normal") != 0 &&
                   strcmp(argv[1], "--missing") != 0))
    {
        fprintf(stderr, "Usage: cjson-demo [--normal | --missing | --version]\n");
        return 64;
    }

    missing = argc == 2 && strcmp(argv[1], "--missing") == 0;
    input = missing ? "{}" : "{\"name\":\"Original name\"}";
    printf("Input: %s\n", input);
    config = cJSON_Parse(input);
    if (config == NULL)
    {
        fprintf(stderr, "Could not create the demo configuration.\n");
        return 1;
    }

    setting = cJSON_GetObjectItemCaseSensitive(config, "name");
    puts("Calling cJSON_SetValuestring...");
    /* Deliberately pass a missing lookup result into the library to exercise
       its historical NULL-handling bug. Production code should validate
       lookup results as well. There is no version-based behavior simulation. */
    updated = cJSON_SetValuestring(setting, "Updated name");
    if (updated == NULL)
    {
        puts("RESULT: missing setting rejected safely.");
        cJSON_Delete(config);
        return 2; /* Handled invalid input, distinct from an access violation. */
    }

    if (missing || strcmp(updated, "Updated name") != 0)
    {
        fprintf(stderr, "Unexpected library result.\n");
        cJSON_Delete(config);
        return 1;
    }
    printf("Updated name: %s\n", updated);
    puts("RESULT: normal update succeeded.");
    cJSON_Delete(config);
    return 0;
}
