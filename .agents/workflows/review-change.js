// review-change.js — 可复用 workflow 示例：只读多维评审 + 对抗校验 + 综合报告。
// 保存：muse workflows save review-change --from .agents/workflows/review-change.js --scope project
// 运行：`muse workflows run` 系 QA 通道（`muse workflows --help` 明示，不在主 help 广告）；
//   日常评审直接派子代理按 code-review SKILL 执行，或等官方 run 开放后再用。
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
  const gaps = [];   // 阶段缺口：缺失/出错/未完成（机器可判）
  const unres = [];  // 上游未决：review/verify/synthesis 的 data.unresolved（带出处，不吞）
  reports.forEach((r, i) => {
    const tag = "review#" + i + ":" + ((r && r.ref) || "missing-result");
    if (r && r.ref) refs.push(r.ref);
    if (!ok(r)) { gaps.push(tag); return; }
    for (const u of (r.data.unresolved || [])) unres.push(tag + " " + u);
  });
  // Stage 2: 对抗验证。fresh 视角逐条执行 verificationQuestion，confirmed 才进综合。
  const verification = await host.agent({
    label: "verify",
    schema: findingSchema,
    input: "你是验证者，不是复述者。对以下评审报告的每条 finding 执行它的 verificationQuestion（打开文件正文独立验证，不许复述评审结论）： " + refs.join(" ") + "。输出 confirmed（证据成立，注明验证路径）或 rejected（证据不足，注明理由）。返回 complete/evidence/unresolved，evidence 只收 confirmed 条目。"
  });
  if (!verification || verification.error_kind) gaps.push("verification-missing");
  else if (!verification.data) gaps.push("verification-no-data");
  else {
    if (verification.data.complete !== true) gaps.push("verification-incomplete");
    for (const u of (verification.data.unresolved || [])) unres.push("verify:" + u);
  }
  // Stage 3: 综合（仅 confirmed；未决原样保留，不得吞掉）。
  const synthesis = await host.agent({
    label: "synthesis",
    schema: evidenceSchema,
    input: "基于已验证 findings（" + ((verification && verification.ref) || "无") + "）综合为优先级报告（P0/P1/P2），保留每条证据的 path:行出处与未决项；rejected 条目不得进入 P0/P1；以下上游未决必须原样列入报告未决节，不得丢弃：" + JSON.stringify(unres) + "。评审原文 refs：" + refs.join(" ")
  });
  const sData = synthesis && !synthesis.error_kind && synthesis.data ? synthesis.data : null;
  if (!synthesis || synthesis.error_kind) gaps.push("synthesis-missing");
  else if (!synthesis.data) gaps.push("synthesis-no-data");
  else {
    if (synthesis.data.complete !== true) gaps.push("synthesis-incomplete");
    for (const u of (synthesis.data.unresolved || [])) unres.push("synthesis:" + u);
  }
  const stages = {
    reviewed: reports.every(ok),
    verified: !!(verification && !verification.error_kind && verification.data && verification.data.complete === true),
    synthesized: !!(sData && sData.complete === true)
  };
  const covered = stages.reviewed && stages.verified && stages.synthesized && gaps.length === 0 && unres.length === 0;
  return {
    status: covered ? "complete" : "partial",
    stages: stages,
    ref: synthesis ? synthesis.ref : null,
    refs: refs,
    verifyRef: verification ? verification.ref : null,
    unresolved: gaps.concat(unres),
    notes: ["read-only run: no files written", "synthesis covers confirmed findings only",
      "status=complete 仅=执行结束且覆盖完整；质量 verdict 见综合报告 P 分级",
      "unresolved 非空或任一 complete=false 即 partial；未证实 finding ≠ 没有问题"]
  };
}
