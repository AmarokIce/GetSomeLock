module encodec;
import std.conv : to;

ubyte[] encrypt(string keyword, ubyte[] pBytes) {
    ubyte[] bytes = new ubyte[0];

    int indexKey = 0;
    foreach (ubyte c; pBytes) {
        char k = keyword[indexKey++];
        ubyte cK = to!ubyte(k);

        bytes ~= c ^ cK;

        if (indexKey == keyword.length) {
            indexKey = 0;
        }
    }

    return bytes;
}

void encryptTo(string keyword, ubyte[] bytes, ubyte[]* object) {
    *object ~= encrypt(keyword, bytes);
}

void encryptToFile(string keyword, string filePath, string newPath = "./", string defPath = "") {
    import std.file, std.string;
    import esstool.arrayutil : len;
    import esstool.stringbuilder : StringBuilder;


    ubyte[] bytes = cast(ubyte[]) read(filePath);

    ubyte[] output;
    encryptTo(keyword, bytes, &output);

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
    string patch = (filePath.replace(defPath, "").replace(name, "")).replace("//", "/");

    string namePatchString = realName ~ ";" ~ fileType;
    ubyte[] patchByte = new ubyte[0];
    foreach(char c; namePatchString) {
        patchByte ~= to!ubyte(c);
    }

    ubyte[] namePatch;
    encryptTo(keyword, patchByte, &namePatch);

    if (!exists(newPath ~ patch)) {
        mkdir(newPath ~ patch);
    }

    write(newPath ~ patch ~ realName ~ ".lock", hash ~ "\n");

    // TODO - Will fix
    append(newPath ~ patch ~ realName ~ ".lock", namePatch ~ '\n');
    append(newPath ~ patch ~ realName ~ ".lock", output);
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
