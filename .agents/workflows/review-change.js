// review-change.js — 可复用 workflow 示例：只读多维评审 + 对抗校验 + 综合报告。
// 保存：muse workflows save review-change --from .agents/workflows/review-change.js --scope project
// 运行：Run the saved review-change workflow against my current changes.
// 约束（官方）：终值必须 JSON 可序列化；只读子留共享区；本脚本只读，不写任何文件。
// 流程来源：cc-base workflows/code-review-fanout.js（Review→Verify→综合，confirmed-only）。
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
  const findingSchema = {
    type: "object",
    required: ["complete", "evidence", "unresolved"],
    properties: {
      complete: { type: "boolean" },
      evidence: { type: "array", items: { type: "string" } },
      unresolved: { type: "array", items: { type: "string" } }
    }
  };
  // Stage 1: 三维只读评审。每条 finding 必须带 file:line 或复现路径 + verificationQuestion。
  const reports = await host.parallel([
    { label: "api-design", schema: evidenceSchema, input: "只读评审当前变更的 API 设计：兼容性、命名、错误契约。每个结论必须打开文件正文取证（search 只定位）。每条 finding 附一行 verificationQuestion（一个能证伪它的具体检查）。返回 complete/evidence/unresolved，evidence 形如 path:行: 发现 | verificationQuestion: ..." },
    { label: "security", schema: evidenceSchema, input: "只读评审当前变更的安全边界：注入、路径穿越、密钥、权限。每个结论必须打开文件正文取证。每条 finding 附一行 verificationQuestion。返回 complete/evidence/unresolved。" },
    { label: "tests", schema: evidenceSchema, input: "只读评审当前变更的测试覆盖：触及面是否有锁定测试、边界/负例是否覆盖。每个结论必须打开文件正文取证。每条 finding 附一行 verificationQuestion。返回 complete/evidence/unresolved。" }
  ]);
  const ok = (r) => r !== null && !r.error_kind && r.data && r.data.complete === true;
  const refs = [];
  const gaps = [];
  for (const r of reports) {
    if (r && r.ref) refs.push(r.ref);
    if (!ok(r)) gaps.push((r && r.ref) || "missing-result");
  }
  // Stage 2: 对抗验证。fresh 视角逐条执行 verificationQuestion，confirmed 才进综合。
  const verification = await host.agent({
    label: "verify",
    schema: findingSchema,
    input: "你是验证者，不是复述者。对以下评审报告的每条 finding 执行它的 verificationQuestion（打开文件正文独立验证，不许复述评审结论）： " + refs.join(" ") + "。输出 confirmed（证据成立，注明验证路径）或 rejected（证据不足，注明理由）。返回 complete/evidence/unresolved，evidence 只收 confirmed 条目。"
  });
  const vOk = verification !== null && !verification.error_kind;
  if (!vOk) gaps.push("verification-missing");
  // Stage 3: 综合（仅 confirmed）。
  const synthesis = await host.agent({
    label: "synthesis",
    schema: evidenceSchema,
    input: "基于已验证 findings（" + ((verification && verification.ref) || "无") + "）综合为优先级报告（P0/P1/P2），保留每条证据的 path:行出处与未决项；rejected 条目不得进入 P0/P1。评审原文 refs：" + refs.join(" ")
  });
  const sData = synthesis && !synthesis.error_kind && synthesis.data ? synthesis.data : null;
  return {
    status: gaps.length === 0 && sData && sData.complete === true ? "complete" : "partial",
    ref: synthesis ? synthesis.ref : null,
    refs: refs,
    verifyRef: verification ? verification.ref : null,
    unresolved: gaps,
    notes: ["read-only run: no files written", "synthesis covers confirmed findings only"]
  };
}
