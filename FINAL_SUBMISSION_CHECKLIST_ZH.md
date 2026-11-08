# ELEC5305 最终提交清单（中文版）

截止时间：Canvas 页面显示 **2026 年 11 月 13 日 23:59**。

## 你最后要交什么

根据 Canvas 的 `Project Submission Details` 和 `What to Hand In`：

1. **Canvas：最终报告 PDF**
2. **Canvas：演示视频**
3. **GitHub：能运行的代码、说明、结果、报告，以及视频链接**

不要把“一个 ZIP 压缩包”当成唯一提交物。ZIP 只适合自己备份；Canvas 的正式提交应当是报告 PDF 和视频，GitHub 链接已经写进报告。

## 第一步：在 MATLAB 里做最终运行检查

1. 打开文件夹 `elec5305-project-530668932`。
2. 打开 MATLAB。
3. 把 MATLAB 的“当前文件夹”切换到这个项目文件夹。
4. 在命令行粘贴：

```matlab
run('code/run_final_project.m')
```

5. 等待运行结束。
6. 如果没有红色报错，检查 `results/final` 里面是否有：
   - `final_metrics.csv`
   - `final_summary.csv`
   - 四张 PNG 图
   - `audio_demo` 文件夹和四个 WAV 文件
7. 如果 MATLAB 出现红色报错，**不要提交**，直接把完整报错截图发来。

## 第二步：录制 4–5 分钟视频

1. 打开 `VIDEO_SCRIPT_EN_WITH_ZH_GUIDE.md`。
2. 使用 Windows 自带录屏：按 `Win + G`，打开“捕获”，开始录制。
3. 一边显示 MATLAB、代码和结果图，一边照着英文稿说。
4. 保存为 MP4，建议文件名：

`ELEC5305_Project_Video_Zhizhong_Chen_530668932.mp4`

5. 完整播放一次，确认有画面、有声音、没有录到密码或私人通知。

## 第三步：获得视频链接

推荐把视频上传为以下任一种：

- YouTube 的“不公开列出 / Unlisted”；或
- OneDrive 中设置为“任何拥有链接的人可以查看”。

复制最终视频链接。把链接发给我，我会把它写进 `README.md` 和最终报告 PDF，再给你最后版本。

## 第四步：更新 GitHub

GitHub 仓库地址：

<https://github.com/czz0806/elec5305-project-530668932>

必须上传或更新：

- `README.md`
- `code/run_final_project.m`
- `audio/` 文件夹
- `results/final/` 文件夹
- `ELEC5305_Final_Project_Zhizhong_Chen_530668932.pdf`
- 视频链接（写在 README 的 `Video demonstration` 部分）

上传后，打开下面网页，确认图片和链接能显示：

<https://czz0806.github.io/elec5305-project-530668932/>

## 第五步：Canvas 最终提交

1. 点击 `Submit Assignment`。
2. 上传最终 PDF：

`ELEC5305_Final_Project_Zhizhong_Chen_530668932.pdf`

3. 上传最终 MP4 视频；如果 Canvas 允许填写链接，也同时粘贴视频链接。
4. 再检查一次文件名和预览。
5. 点击正式提交。
6. 提交后确认页面出现提交时间和两个文件。
7. 下载 Canvas 中已提交的 PDF，再打开一次，确认没有损坏。

## 当前项目最重要的结果

- 32 个条件中，Wiener filtering 的 SNR improvement 全部更高。
- 平均 SNR improvement：Wiener `2.945 dB`；spectral subtraction `2.090 dB`。
- 平均 LSD（越低越好）：spectral subtraction `10.334 dB`；Wiener `10.772 dB`。
- 结论不是“谁绝对更好”，而是噪声抑制和语音频谱失真之间存在 trade-off。

