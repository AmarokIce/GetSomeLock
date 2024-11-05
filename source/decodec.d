module decodec;

import std.conv : to;

ubyte[] decrypt(string keyword, ubyte[] pBytes) {
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

void decryptTo(string keyword, ubyte[] bytes, ubyte[]* object) {
    *object ~= decrypt(keyword, bytes);
}

bool decryptFromFile(string keyword, string filePath, string newPath = "./", string defPath = "") {
    import std.array, std.string, std.file;

    ubyte[] bytes = cast(ubyte[]) read(filePath);
    ubyte[][] lines = bytes.split(to!ubyte('\n'));

    string hash = to!string(hashOf(keyword));
    if (lines[0] != hash) {
        return false;
    }

    ubyte[] infoByte = decrypt(keyword, lines[1]);
    string info = "";
    foreach(ubyte b; infoByte) {
        info ~= to!char(b);
    }

    string[] infoData = info.split(";");
    string fileName = infoData[0];
    string fileType = infoData[1];

    fileName = (fileName == "NaN" ? "" : fileName) ~ (fileType == "NaN" ? "" : "." ~ fileType);

    auto patch = filePath.replace(defPath, "").replace(filePath.split("/")[$ - 1], "");
    if (!exists(newPath ~ patch)) {
        mkdir(newPath ~ patch);
    }

    ubyte[] data;
    decryptTo(keyword, lines[2], &data);
    write(newPath ~ patch ~ fileName, data);
    return true;
}

import std.concurrency;
import core.atomic;

static void threadFunction(shared(int)* counter, shared(int)* fails, string keyword,
    string path, string newPath, string defPath) {
    if (!decryptFromFile(keyword, path, newPath, defPath) && fails != null) {
        (*fails).atomicOp!"+="(1);
    }

    (*counter).atomicOp!"+="(1);
}

void decryptFromFiles(string keyword, string[] filePaths,
    shared(int)* counter = null, shared(int)* fails = null,
    string newPath = "./", string defPath = "") {
    import esstool.arrayutil : len;

    shared int finishThreads = 0;
    int maxFiles = len(filePaths);

    foreach (string path; filePaths) {
        spawn(&threadFunction, &finishThreads, fails, keyword, path, newPath, defPath);
    }

    do {
        if (counter != null)
            (*counter).atomicStore(finishThreads.atomicLoad);
    }
    while (finishThreads.atomicLoad() < maxFiles);
}
