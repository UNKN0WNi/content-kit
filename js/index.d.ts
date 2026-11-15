/** content-kit : 跨端内容抽取与规范化内核（js 后端 npm 包） */

/** 抽取结果的紧凑 JSON 字符串（字段顺序固定，四后端逐字节一致）。 */
export declare function extractJson(html: string): string;

/** 抽取结果的纯文本渲染。 */
export declare function extractText(html: string): string;

/** 抽取结果的 Markdown 渲染。 */
export declare function extractMd(html: string): string;

/** 当前规则表版本（例如 "1.0.0"）。 */
export declare function rulesVersion(): string;

/** 全量语料的 Golden Bundle：`名称<TAB>JSON` 逐行，用于跨后端一致性比对。 */
export declare function goldenBundle(): string;

/** 结构化输出中的单个内容块。 */
export type ContentBlock =
  | { kind: "paragraph"; text: string }
  | { kind: "heading"; level: number; text: string }
  | { kind: "list_item"; text: string }
  | { kind: "quote"; text: string }
  | { kind: "code"; text: string }
  | { kind: "image"; src: string; alt: string | null };

/** extractJson 反序列化后的形状。 */
export interface Article {
  title: string;
  byline: string | null;
  site_name: string | null;
  excerpt: string | null;
  lead_image: string | null;
  lang: string | null;
  published_at: string | null;
  blocks: ContentBlock[];
  text: string;
  markdown: string;
  metadata: {
    site_name: string | null;
    description: string | null;
    lead_image: string | null;
    lang: string | null;
    published_at: string | null;
    keywords: string[];
    jsonld: string | null;
  };
  score: number;
  rules_version: string;
}
