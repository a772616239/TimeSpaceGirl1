#!/usr/local/bin/bash
# 转发到共享实现 —— 本文件只是为了让 job 里既有的 .jenkins/lib/run_stage.sh 路径继续有效。
# 真正的代码在：/Users/wangxufeng/Documents/jenkins-shared/lib/run_stage.sh
# 改逻辑请改共享库；这里保持 "参数原样透传" 的语义，不要在这里加分支。
exec /usr/local/bin/bash "/Users/wangxufeng/Documents/jenkins-shared/lib/run_stage.sh" "$@"
