///|
/// 内置语料库（Golden Vector）。所有 HTML 都是快照，不依赖网络。
/// 覆盖：中文/英文、新闻/博客/文档/论坛、元数据优先级、实体、畸形 HTML、
/// script 伪标签、无正文页、纯文本、空输入、Unicode 代理对。

///|
pub fn cases() -> Array[(String, String)] {
  let news_cn =
    #| <!DOCTYPE html>
    #| <html lang="zh-CN"><head>
    #| <title>月球基地开始运行 - 每日科学</title>
    #| <meta name="author" content="林深">
    #| <meta name="description" content="我国首个月球科研基地正式投入运行。">
    #| <meta name="keywords" content="月球, 航天, 科研">
    #| <meta property="og:title" content="月球基地开始运行">
    #| <meta property="og:site_name" content="每日科学">
    #| <meta property="og:image" content="https://example.com/moon.jpg">
    #| <meta property="og:description" content="月球基地正式投入运行的现场报道。">
    #| <meta property="article:published_time" content="2026-11-14T08:00:00Z">
    #| <script type="application/ld+json">{"@context":"https://schema.org","@type":"NewsArticle","headline":"来自 JSON-LD 的标题","description":"来自 JSON-LD 的摘要","datePublished":"2026-11-14","author":{"@type":"Person","name":"赵岩"},"publisher":{"name":"每日科学"},"image":["https://example.com/ld.jpg"]}</script>
    #| <style>.ad { display:none }</style>
    #| </head><body>
    #| <header><div class="site-nav"><a href="/">首页</a> <a href="/sci">科学</a> <a href="/tech">科技</a></div></header>
    #| <nav class="navigation">导航链接 导航链接 导航链接 导航链接</nav>
    #| <aside class="sidebar"><div class="advert"><a href="/buy">广告位招租 广告位招租 广告位招租</a></div><div class="related">相关文章 相关文章 相关文章 相关文章 相关文章</div></aside>
    #| <article id="content" role="article" itemprop="articleBody">
    #| <h1>月球基地开始运行</h1>
    #| <p class="byline">作者：林深　发布时间：2026-11-14</p>
    #| <p>我国首个月球科研基地于今日正式投入运行，首批六名科研人员已进驻，将开展为期三个月的原位资源利用实验。基地配备了生命保障系统、能源系统与样品分析实验室，可支持长期驻留。</p>
    #| <p>据介绍，本次任务重点验证月壤制氧、水冰提取与 3D 打印建材三项关键技术。实验数据将通过中继星实时回传，并在地面完成复核与分析，后续结果会分批公布。</p>
    #| <h2>后续计划</h2>
    #| <p>项目团队计划在下一阶段扩大基地规模，引入更多国际合作载荷，并开展面向深空探测的长期生物学实验，为载人登月积累工程经验。</p>
    #| <blockquote>月球不是终点，而是通往更远深空的中转站。</blockquote>
    #| <figure><img src="https://example.com/base.jpg" alt="月球基地全景"><figcaption>基地全景照片，摄于着陆后第三日。</figcaption></figure>
    #| <ul><li>生命保障系统已完成 72 小时连续测试</li><li>首批样品分析数据回传正常</li></ul>
    #| <pre><code>temperature = -23.5 C
    #| status = nominal</code></pre>
    #| </article>
    #| <footer class="footer">版权所有 每日科学 联系我们 关于我们 备案号</footer>
    #| <script>var fake = "<p>这段脚本里的伪标签不应进入正文</p>";</script>
    #| </body></html>

  let blog_en =
    #| <html lang="en"><head><title>Understanding WASM GC | Byte Notes</title>
    #| <meta name="description" content="A short introduction to WASM GC.">
    #| <meta name="author" content="Ada Lovelace">
    #| </head><body>
    #| <div class="header"><a href="/">Home</a><a href="/about">About</a><a href="/archive">Archive</a></div>
    #| <div class="sidebar advert"><a href="/sponsor">Sponsored link Sponsored link Sponsored link</a></div>
    #| <div id="main-content"><article>
    #| <h1>Understanding WASM GC</h1>
    #| <p>WASM GC gives WebAssembly a native reference type system, so languages with managed memory no longer need to ship their own garbage collector inside the linear memory. This reduces both binary size and startup time significantly.</p>
    #| <p>The proposal introduces struct and array types, along with typed references. Compilers can now emit allocations that the host runtime understands, and the runtime can collect them without scanning a black-box heap, which is a substantial change.</p>
    #| <h2>Why it matters for edge computing</h2>
    #| <p>Edge workers care about cold start latency above everything else. A smaller module with fewer runtime dependencies starts faster, and that is exactly what the GC proposal enables for compiled languages targeting the web platform today.</p>
    #| <ul><li>Smaller binaries</li><li>Faster cold starts</li><li>Better interoperability with JavaScript objects</li></ul>
    #| </article></div>
    #| <div class="comments"><p>Comment one Comment one Comment one</p><p>Comment two Comment two Comment two</p></div>
    #| <footer>Footer links Footer links Footer links</footer>
    #| </body></html>

  let docs =
    #| <html><head><title>API Reference - content-kit</title>
    #| <meta name="description" content="API reference documentation">
    #| </head><body>
    #| <nav>Docs API Guides Blog GitHub</nav>
    #| <main><article>
    #| <h1>extract(html)</h1>
    #| <p>The extract function parses an HTML document and returns a normalized Article. It is a pure function: the same input always yields the same output on every supported backend, byte for byte after JSON serialization.</p>
    #| <pre><code>let article = extract(html)
    #| println(article.title)</code></pre>
    #| <h2>Parameters</h2>
    #| <p>html: a string containing the full document, or a fragment. Malformed input is tolerated and never raises; the parser degrades gracefully and returns an empty article when no content can be found.</p>
    #| <h2>Returns</h2>
    #| <p>An Article record containing the ordered block sequence, the flat text rendering, the Markdown rendering and the resolved metadata fields for downstream consumers.</p>
    #| </article></main>
    #| </body></html>

  let jsonld_only =
    #| <html><head><title>Fallback title</title>
    #| <script type="application/ld+json">{"@type":"Article","headline":"JSON-LD 标题","description":"JSON-LD 摘要","datePublished":"2026-10-01","author":{"name":"钱学森"},"publisher":{"name":"科技日报"},"image":"https://example.com/ld.png"}</script>
    #| </head><body><article><p>这是一篇只有 JSON-LD 元数据的文章，正文段落需要被正确抽取出来，用于验证元数据优先级与正文抽取互不干扰，同时保证字段回退路径可用。</p><p>第二段补充说明：日期、作者、站点名、插图都应当从 JSON-LD 中取得，而标题也必须优先于 head 里的 title 标签。</p></article></body></html>

  let entities =
    #| <html><head><title>Tom &amp; Jerry &lt;Review&gt; &mdash; Site</title></head><body>
    #| <div id="article"><p>AT&amp;T &quot;quoted&quot; &lt;tag&gt; &nbsp; &copy; 2026 &mdash; 中文，标点、测试；结束。</p>
    #| <p>&#65;&#66;&#67; &amp; &#x26; &apos;single&apos; 与数字实体混合出现，需要正确解码后再做空白折叠与长度统计。</p>
    #| </div></body></html>

  let malformed =
    #| <html><head><title>Broken markup</title></head><body>
    #| <div id=content class=post><p>第一段没有闭合标签，解析器应当容错处理而不是崩溃或死循环。
    #| <p>第二段紧随其后，隐式闭合规则需要把它当成独立段落处理，保证文档顺序保持不变。
    #| <div class="advert"><a href="#">广告 广告 广告
    #| <span>孤立的小于号 &lt; 与未知的 &bogus; 实体都要原样保留下来。</span>
    #| </div>
    #| <article><h2>未被闭合的标题</h2><p>最后一段正文内容足够长，以便通过最小文本长度阈值参与打分竞争并成为候选块。</p>

  let no_content =
    #| <html><head><title>门户首页</title></head><body>
    #| <nav><a href="/a">新闻 新闻 新闻 新闻 新闻 新闻 新闻 新闻 新闻 新闻</a></nav>
    #| <div class="menu"><a href="/b">体育 体育 体育 体育 体育 体育 体育 体育 体育 体育</a></div>
    #| <footer>关于我们 联系我们 版权声明 友情链接</footer>
    #| </body></html>

  let plain =
    #| 这是一段纯文本输入，不含有任何 HTML 标签，用于验证兜底解析路径。
    #|
    #| # 一级标题
    #|
    #| 纯文本的第二段，包含逗号，中文标点，以及足够长的内容来形成独立的内容块。
    #|
    #| - 列表项一
    #| - 列表项二
    #|
    #| > 引用内容
    #|
    #| ```
    #| code line one
    #| code line two
    #| ```

  let forum =
    #| <html><head><title>论坛帖子 - 社区</title></head><body>
    #| <div class="comment"><p>沙发 沙发 沙发</p></div>
    #| <div class="comment"><p>板凳 板凳 板凳</p></div>
    #| <div class="comment"><p>路过 路过 路过</p></div>
    #| <div id="post-content"><article>
    #| <h1>关于跨后端一致性的实践总结</h1>
    #| <p>在浏览器扩展、边缘 Worker 与服务端归档三个环境里使用同一份抽取逻辑，最容易出现的问题不是算法效果，而是浮点格式、字段顺序与字符串转义的细微差别。把这些差异消除在序列化层，比在业务层打补丁可靠得多。</p>
    #| <p>我们的做法是把所有权重集中在一张规则表里，让四个后端编译完全相同的源码，再对同一份语料做逐字节比对。这样一致性不是靠人工对齐，而是由构造保证，回归测试也更容易写。</p>
    #| </article></div>
    #| <div class="comment"><p>同意 同意 同意</p></div>
    #| </body></html>

  let meta_priority =
    #| <html lang="fr"><head>
    #| <title>HTML 标题 - 站点</title>
    #| <meta property="og:title" content="OG 标题">
    #| <meta name="twitter:title" content="Twitter 标题">
    #| <meta name="author" content="meta 作者">
    #| <meta property="og:site_name" content="OG 站点">
    #| <meta property="og:description" content="OG 摘要">
    #| <meta name="description" content="Meta 摘要">
    #| <meta name="keywords" content="a,b,c">
    #| <meta http-equiv="content-language" content="fr-FR">
    #| <script type="application/ld+json">{"headline":"JSON-LD 标题","author":"JSON-LD 作者","publisher":"JSON-LD 出版方","description":"JSON-LD 摘要","datePublished":"2026-01-02"}</script>
    #| </head><body><h1>H1 标题</h1><article><p>本用例用于逐项验证元数据字段的优先级顺序：标题、作者、站点名、摘要、发布时间与语言，都应当按照计划书里定义的优先级表进行回退，且不能被低优先级来源覆盖。</p><p>第二段内容保证候选块能够通过最小长度阈值，从而让正文抽取与元数据解析在同一次调用里都被覆盖到。</p></article></body></html>

  let script_noise =
    #| <html><head><title>Script noise</title></head><body>
    #| <script>var html = "<article><h1>Fake heading</h1><p>Fake paragraph with lots and lots of words that should never be extracted into the article body under any circumstances.</p></article>";</script>
    #| <style>/* <p>fake style content</p> */</style>
    #| <article><p>真正的正文只有这一段，脚本与样式里的伪标签全部不应该出现在输出里，用于验证预处理阶段对非内容节点的剥离是否彻底且不影响真实内容。</p></article>
    #| <noscript><p>请启用 JavaScript 以查看评论，这段也不应进入正文。</p></noscript>
    #| </body></html>

  let unicode =
    #| <html><head><title>Emoji 😀 与中文 🇨🇳 - 测试</title></head><body>
    #| <article><h1>代理对与全角标点</h1><p>😀🚀🌕 这是一段包含 emoji、中文全角标点，以及拉丁字母 mixed content 的正文，用来验证按 Unicode 字符计数与截断时不会切坏代理对，同时验证 JSON 转义不依赖后端实现。</p>
    #| <p>第二段：中文，逗号；英文, comma. 混合排版 «quotes» — dash — 结束。</p></article>
    #| </body></html>

  [
    ("news-cn", news_cn),
    ("blog-en", blog_en),
    ("docs", docs),
    ("jsonld-only", jsonld_only),
    ("entities", entities),
    ("malformed", malformed),
    ("no-content", no_content),
    ("plain", plain),
    ("forum", forum),
    ("meta-priority", meta_priority),
    ("script-noise", script_noise),
    ("unicode", unicode),
    ("empty", ""),
    ("tiny", "<p>hi</p>"),
  ]
}

///|
/// 语料名称清单，供 CLI 与测试枚举使用。
pub fn case_names() -> Array[String] {
  let out : Array[String] = []
  for (name, _html) in cases() {
    out.push(name)
  }
  out
}

///|
/// 按名称查找语料。
pub fn case_html(name : String) -> String? {
  for (key, html) in cases() {
    if key == name {
      return Some(html)
    }
  }
  None
}

///|
pub fn case_count() -> Int32 {
  cases().length()
}
