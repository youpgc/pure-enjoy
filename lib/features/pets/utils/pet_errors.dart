/// 宠物 RPC 业务错误文案映射
///
/// PostgREST 4xx 时 error 字段为服务端 message（raise exception 的文本，
/// 如 PET_FREE_FEED_LIMIT）；在此统一转中文，未知码透传原文。
String petRpcErrorText(String? error) {
  final msg = error ?? '';
  // 兜底：服务端错误 JSON 里截取 message 值
  final m = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(msg);
  final code = m?.group(1) ?? msg;
  const map = <String, String>{
    'PET_FREE_FEED_LIMIT': '今日免费喂养次数已用完，可使用背包中的食物',
    'PET_FEED_COOLDOWN': '喂得太快啦，休息一会儿再来',
    'PET_ITEM_NOT_FEED': '该道具不能用于喂养',
    'PET_ITEM_NOT_USABLE': '该道具无法直接使用',
    'PET_NOT_FOUND': '未找到宠物',
    'PET_NOT_REARING': '宠物当前不在养育中',
    'PET_EGG_NOT_FOUND': '未找到该蛋',
    'PET_EGG_NOT_UNOPENED': '该蛋已孵化',
    'PET_POOL_NOT_PUBLISHED': '蛋池未发布，请联系管理员',
    'PET_SPECIES_NOT_AVAILABLE': '暂无可用种属，请联系管理员',
    'PET_REARING_FULL': '养育格已满，请先扩容或寄养',
    'PET_ITEM_NOT_ON_SHELF': '商品已下架',
    'PET_EGG_NOT_ON_SHELF_P1': '该蛋暂不开放购买',
    'PET_INVALID_AMOUNT': '数量无效',
    'PET_BAG_FULL': '背包已满，请先扩容或清理背包',
    'PET_BAG_FULL_RACE': '背包已满，请清理后再试',
    'PET_BAG_FULL_CLAIM_RETRY': '背包已满，清理后可重新领取',
    'PET_STATUS_TOO_LOW': '状态太差，先喂饱再出发吧',
    'PET_SPOT_NOT_FOUND': '历险地不可用',
    'PET_INVALID_TIER': '历险档位无效',
    'PET_ADV_NOT_FOUND': '未找到历险记录',
    'PET_ADV_NOT_ONGOING': '历险已结束',
    'PET_ADV_NOT_FINISHED': '历险还在进行中',
    'PET_ADV_NOT_RESCUE': '当前无需救助',
    'PET_RESCUE_WINDOW_OPEN': '自救窗口内需使用救援道具',
    'PET_QUEST_NOT_FOUND': '任务不存在',
    'PET_QUEST_ALREADY_CLAIMED': '奖励已领取',
    'PET_QUEST_NOT_DONE': '任务还未完成',
    'PET_INSUFFICIENT_GOLD': '金币不足',
    'PET_INSUFFICIENT_POINTS': '积分不足',
    'LADDER_STEP_LOCKED': '请先购买前一档扩容',
    'LADDER_STEP_OWNED': '该档扩容已购买',
    'LADDER_MAX_REACHED': '已达扩容上限',
  };
  if (map.containsKey(code)) return map[code]!;
  if (code.length <= 40) return code;
  return '操作失败，请稍后重试';
}
