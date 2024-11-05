import std.conv : to;
import dlangui;

mixin APP_ENTRY_POINT;

EditLine inputLine;
EditLine outputLine;
EditLine passwordLine;
Button buttonLocked;
Button buttonUnlock;

Window window;
LinearLayout layout;

extern (C) int UIAppMain(string[] args) {
    string[] resourceDirs = [
        appendPath(exePath, "../res/"), // for Visual D and DUB builds
        appendPath(exePath, "../../res/") // for Mono-D builds
    ];

    Platform.instance.uiTheme = "theme_default";
    Platform.instance.uiLanguage = "en";
    Platform.instance.resourceDirs = resourceDirs;

    // Platform.instance.defaultWindowIcon("gsl-logo.png");

    window = Platform.instance.createWindow("Get Some Lock", null, WindowFlag.Modal, 500, 150);

    layout = new VerticalLayout();
    layout.backgroundColor = 0x7ed2f7;

    auto tablelayout = createPathLinesTable();
    createPasswordAndControl(tablelayout);

    layout.addChild(tablelayout);
    window.mainWidget = layout;
    window.show();
    return Platform.instance.enterMessageLoop();
}

TableLayout createPathLinesTable() {
    inputLine = new EditLine(null);
    outputLine = new EditLine(null);

    inputLine.layoutWidth = 500;
    outputLine.layoutWidth = 500;

    auto tablelayout = new TableLayout();
    tablelayout.colCount = 2;
    tablelayout.margins = 40;
    tablelayout.padding = 5;

    tablelayout.addChild(new TextWidget(null, "输入文件（夹）："d));
    tablelayout.addChild(inputLine);
    tablelayout.addChild(new TextWidget(null, "输出文件夹："d));
    tablelayout.addChild(outputLine);

    return tablelayout;
}

void createPasswordAndControl(TableLayout tablelayout) {
    passwordLine = new EditLine(null);
    passwordLine.layoutWidth = 200;

    buttonLocked = new Button(null, "加锁"d);
    buttonUnlock = new Button(null, "解锁"d);

    buttonLocked.layoutWidth = 150;
    buttonUnlock.layoutWidth = 150;

    buttonLocked.click = delegate(Widget src) {
        if (!checkInfo()) {
            window.showMessageBox("错误", "缺少输入/输出路径或密码为空！");

            return true;
        }

        lock();
        window.showMessageBox("成功", "完成！");

        return true;
    };

    buttonUnlock.click = delegate(Widget src) {
        if (!checkInfo()) {
            window.showMessageBox("错误", "缺少输入/输出路径或密码为空！");
            return true;
        }

        bool hasFails = unlock();
        if (!hasFails) {
            window.showMessageBox("警告", "工作已结束，但存在未能解锁的文件，这可能是因为密码不正确！");
        } else {
            window.showMessageBox("成功", "完成！");
        }
        return true;
    };

    tablelayout.addChild(new TextWidget(null, "秘钥："d));

    HorizontalLayout horizontalLayout = new HorizontalLayout();
    horizontalLayout.addChild(passwordLine);
    horizontalLayout.addChild(buttonLocked);
    horizontalLayout.addChild(buttonUnlock);

    tablelayout.addChild(horizontalLayout);
}

bool checkInfo() {
    auto inputPath = inputLine.text;
    auto outputPath = outputLine.text;

    auto password = passwordLine.text;

    return inputPath.length > 0 && outputPath.length > 0 && password.length > 0;
}

import std.file, std.string, std.array;

void lock() {
    import encodec;

    string inputPath = to!string(inputLine.text).replace("\\", "/").replace("//", "/");
    string outputPath = to!string(outputLine.text).replace("\\", "/").replace("//", "/");
    string password = to!string(passwordLine.text);

    bool flag = inputPath.isFile();
    if (!outputPath.exists()) {
        mkdir(outputPath);
    }

    if (!outputPath.endsWith("/")) {
        outputPath ~= "/";
    }

    if (flag) {
        encryptToFile(password, inputPath, outputPath, inputPath.replace(
                inputPath.split("/")[$ - 1], ""));
        return;
    }

    if (!inputPath.endsWith("/")) {
        inputPath ~= "/";
    }

    string[] paths = new string[0];
    foreach (DirEntry dire; dirEntries(inputPath, SpanMode.breadth)) {
        if (dire.isFile()) {
            paths ~= dire.name.replace("\\", "/").replace("//", "/");
        }
    }

    auto str = to!string(paths);

    encryptToFiles(password, paths, null, outputPath, inputPath);
}

bool unlock() {
    import decodec;

    string inputPath = to!string(inputLine.text).replace("\\", "/").replace("//", "/");
    string outputPath = to!string(outputLine.text).replace("\\", "/").replace("//", "/");
    string password = to!string(passwordLine.text);

    bool flag = inputPath.isFile();
    if (!outputPath.exists()) {
        mkdir(outputPath);
    }

    if (!outputPath.endsWith("/")) {
        outputPath ~= "/";
    }

    if (flag) {
        return decryptFromFile(password, inputPath, outputPath, inputPath.replace(
                inputPath.split("/")[$ - 1], ""));
    }

    if (!inputPath.endsWith("/")) {
        inputPath ~= "/";
    }

    string[] paths = new string[0];
    foreach (DirEntry dire; dirEntries(inputPath, SpanMode.breadth)) {
        if (dire.isFile()) {
            paths ~= dire.name.replace("\\", "/").replace("//", "/");
        }
    }

    import core.atomic;

    shared int fails = 0;
    decryptFromFiles(password, paths, null, &fails, outputPath, inputPath);

    return fails.atomicLoad == 0;
}
