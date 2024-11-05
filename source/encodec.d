module encodec;
import std.conv : to;

/**
 * Encrypt the object.
 *
 * Params:
 *   keyword = The key for encrypt.
 *   text = The object will encrypt.
 */
char[] encrypt(string keyword, string text) {
    char[] bytes = new char[0];

    int indexKey = 0;
    foreach (char c; text) {
        char k = keyword[indexKey++];
        int cK = to!uint(k);
        int cC = to!uint(c);

        bytes ~= to!char(cC + cK);

        if (indexKey == keyword.length) {
            indexKey = 0;
        }
    }

    return bytes;
}

/**
* A function for thread
*/
void encryptTo(string keyword, string text, string* object) {
    *object ~= encrypt(keyword, text);
}

void encryptToFile(string keyword, string filePath, string newPath = "./", string defPath = "") {
    import std.file, std.string;
    import esstool.arrayutil : len;
    import esstool.stringbuilder : StringBuilder;


    ubyte[] bytes = cast(ubyte[]) read(filePath);
    string text = "";
    foreach (ubyte b; bytes) {
        text ~= to!char(b);
    }

    string output;
    encryptTo(keyword, text, &output);

    string[] arr = filePath.split("/");
    string name = arr[$ - 1];
    arr = name.split(".");

    string realName;
    string fileType;

    if (len(arr) < 2) {
        if (new StringBuilder(name).indexOf(".") != -1) {
            realName = name;
            fileType = "NaN";
        } else {
            realName = "NaN";
            fileType = arr[0];
        }
    } else {
        realName = arr[0];
        fileType = arr[1];
    }

    string hash = to!string(hashOf(keyword));

    string type = to!string(encrypt(keyword, realName ~ ";" ~ fileType));

    string patch = (filePath.replace(defPath, "").replace(name, "")).replace("//", "/");

    if (!exists(newPath ~ patch)) {
        mkdir(newPath ~ patch);
    }

    write(newPath ~ patch ~ realName ~ ".lock", hash ~ "\n");
    append(newPath ~ patch ~ realName ~ ".lock", type ~ "\n");
    append(newPath ~ patch ~ realName ~ ".lock", output ~ "\n");
}

import std.concurrency;
import core.atomic;

static void threadFunction(shared(int)* counter, string keyword, string path, string newPath, string defPath) {
    encryptToFile(keyword, path, newPath, defPath);
    (*counter).atomicOp!"+="(1);
}

void encryptToFiles(string keyword, string[] filePaths, shared(int)* counter = null,
    string newPath = "./", string defPath = "") {
    import esstool.arrayutil : len;

    shared int finishThreads = 0;
    int maxFiles = len(filePaths);

    foreach (string path; filePaths) {
        spawn(&threadFunction, &finishThreads, keyword, path, newPath, defPath);
    }

    do {
        if (counter != null)
            (*counter).atomicStore(finishThreads.atomicLoad);
    }
    while (finishThreads.atomicLoad() < maxFiles);
}
