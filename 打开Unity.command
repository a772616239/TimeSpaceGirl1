#!/bin/bash
#Unity命令行手册：https://docs.unity3d.com/cn/current/Manual/CommandLineArguments.html
echo "-----开始运行"

#Unity程序的路径
unityPath=/Applications/Unity2018.4.36f1/Unity.app/Contents/MacOS/Unity

#项目路径
projectPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "-----Unity程序路径：$unityPath"
echo "-----项目路径：$projectPath"

#打开Unity 项目路径 项目产生的日志输出到控制台 执行方法 Editor文件夹下的类名.静态方法名 执行完退出Unity层序 批处理模式不弹出窗口
"$unityPath" -projectPath "$projectPath"