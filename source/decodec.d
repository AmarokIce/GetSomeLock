module decodec;

import std.conv : to;
import app;

string decrypt(string keyword, string text) {
    string str = "";

    int indexKey = 0;
    foreach (char c; text) {
        char k = keyword[indexKey++];
        int cK = to!uint(k);
        int cC = to!uint(c);

        str ~= to!char(cC - cK);

        if (indexKey == keyword.length) {
            indexKey = 0;
        }
    }

    return str;
}

void decryptTo(string keyword, string text, string* object) {
    *object ~= decrypt(keyword, text);
}

bool decryptFromFile(string keyword, string filePath, string newPath = "./", string defPath = "") {
    import std.string;
    import std.file;

    ubyte[] bytes = cast(ubyte[]) read(filePath);
    string text = "";
    foreach (ubyte b; bytes) {
        text ~= to!char(b);
    }

    string[] lines = text.replace("\r", "").split("\n");

    string hash = to!string(hashOf(keyword));

    if (lines[0] != hash) {
        return false;
    }

    string[] info = decrypt(keyword, lines[1]).split(";");
    string fileName = info[0];
    string fileType = info[1];

    fileName = (fileName == "NaN" ? "" : fileName) ~ (fileType == "NaN" ? "" : "." ~ fileType);

    auto patch = filePath.replace(defPath, "").replace(filePath.split("/")[$ - 1], "");
    if (!exists(newPath ~ patch)) {
        mkdir(newPath ~ patch);
    }

    string data = decrypt(keyword, lines[2]);
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
