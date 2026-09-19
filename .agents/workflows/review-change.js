// review-change.js — 可复用 workflow 示例：只读多维评审 + 对抗校验 + 综合报告。
// 保存：muse workflows save review-change --from .agents/workflows/review-change.js --scope project
// 运行：Run the saved review-change workflow against my current changes.
// 约束（官方）：终值必须 JSON 可序列化；只读子留共享区；本脚本只读，不写任何文件。
export default async function workflow(host) {
  const evidenceSchema = {
    type: "object",
    required: ["complete", "evidence", "unresolved"],
    properties: {
      complete: { type: "boolean" },
      evidence: { type: "array", items: { type: "string" } },
      unresolved: { type: "array", items: { type: "string" } }
    }
  };
  const reports = await host.parallel([
    { label: "api-design", schema: evidenceSchema, input: "只读评审当前变更的 API 设计：兼容性、命名、错误契约。每个结论必须打开文件正文取证（search 只定位）。返回 complete/evidence/unresolved，evidence 形如 path:行: 发现。" },
    { label: "security", schema: evidenceSchema, input: "只读评审当前变更的安全边界：注入、路径穿越、密钥、权限。每个结论必须打开文件正文取证。返回 complete/evidence/unresolved。" },
    { label: "tests", schema: evidenceSchema, input: "只读评审当前变更的测试覆盖：触及面是否有锁定测试、边界/负例是否覆盖。每个结论必须打开文件正文取证。返回 complete/evidence/unresolved。" }
  ]);
  const ok = (r) => r !== null && !r.error_kind && r.data && r.data.complete === true;
  const gaps = [];
  const refs = [];
  for (const r of reports) {
    if (r && r.ref) refs.push(r.ref);
    if (!ok(r)) gaps.push((r && r.ref) || "missing-result");
  }
  const synthesis = await host.agent({
    label: "synthesis",
    schema: evidenceSchema,
    input: "综合以下只读评审报告为一份优先级排序报告（P0/P1/P2），保留每条证据的 path:行出处与未决项： " + refs.join(" ")
  });
  const sData = synthesis && !synthesis.error_kind && synthesis.data ? synthesis.data : null;
  return {
    status: gaps.length === 0 && sData && sData.complete === true ? "complete" : "partial",
    ref: synthesis ? synthesis.ref : null,
    refs: refs,
    unresolved: gaps,
    notes: ["read-only run: no files written"]
  };
}
