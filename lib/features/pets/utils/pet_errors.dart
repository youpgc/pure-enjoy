/// 客户端本地异常（字段类型不符、解析失败）的统一文案。
///
/// 原始异常已在各查询点 debugPrint；把 `e.toString()` 直接回给页面会把
/// `type 'Null' is not a subtype of ...` 这类英文串上屏（[petRpcErrorText]
/// 对短字符串是原样放行的），用户读不懂，也掩盖了真正的配置问题。
const String kPetLocalError = '数据读取异常，请刷新重试';

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
    'PET_INTERACT_LIMIT': '今天陪它玩够久啦，明天再来互动吧',
    'PET_INTERACT_COOLDOWN': '它还在回味刚才的抚摸，稍等一下',
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
    'PET_ITEM_NOT_FOUND': '道具不存在或已下架',
    'PET_ITEM_NOT_RESCUE': '该道具不是救援道具，无法用于救助',
    'PET_ITEM_PURCHASE_LIMIT': '该商品已达限购数量',
    'PET_BAG_FULL_RACE': '背包已满，请清理后再试',
    'PET_BAG_FULL_CLAIM_RETRY': '背包已满，清理后可重新领取',
    'PET_STATUS_TOO_LOW': '状态太差，先喂饱再出发吧',
    'PET_LEVEL_TOO_LOW': '宠物等级还达不到这里的要求',
    'PET_HEALTH_TOO_LOW': '宠物健康状况不佳，恢复健康后再出发吧',
    'PET_INVALID_ATTR': '属性类型无效',
    'PET_ATTR_POINTS_INVALID': '可分配点数不足或数量无效',
    'PET_NOTHING_TO_REFINE': '这只宠物还没有升级加点，无可重掷的属性',
    'PET_REFINE_POINTS_INSUFFICIENT': '洗练点不足，使用「属性洗练剂」可补充',
    'PET_ITEM_INSUFFICIENT': '道具数量不足',
    'PET_SPOT_NOT_FOUND': '历险地不可用',
    'PET_INVALID_TIER': '历险档位无效',
    'PET_ADV_NOT_FOUND': '未找到历险记录',
    'PET_ADV_NOT_ONGOING': '历险已结束',
    'PET_ADV_NOT_FINISHED': '历险还在进行中',
    'PET_ADV_NOT_RESCUE': '当前无需救助',
    'PET_ADV_NOT_RECALLABLE': '遇险中的宠物需先救助，无法召回',
    'PET_RESCUE_WINDOW_OPEN': '自救窗口内需使用救援道具',
    'PET_QUEST_NOT_FOUND': '任务不存在',
    'PET_QUEST_ALREADY_CLAIMED': '奖励已领取',
    'PET_QUEST_NOT_DONE': '任务还未完成',
    'PET_GOLD_INSUFFICIENT': '金币不足',
    'PET_POINTS_INSUFFICIENT': '积分不足',
    'PET_POINTS_NOT_ALLOWED': '该操作不支持积分支付',
    'PET_INVALID_CURRENCY': '支付方式不支持',
    'PET_NOT_EXPANSION': '该道具不是扩容道具',
    'PET_INVALID_LADDER': '扩容档位配置异常，请联系管理员',
    'PET_CAPACITY_MAX': '已达扩容上限',
    'PET_LADDER_ORDER': '请先购买前一档扩容',
    'PET_INVALID_SLOT': '格位无效',
    'PET_SLOT_EMPTY': '该格位没有道具',
    'PET_INVALID_INPUT': '操作参数无效',
    'PET_INVALID_ACTION': '操作类型无效',
    'PET_FOSTER_FULL': '寄养格不够用，可在商城「扩容」分类购买寄养扩容',
    'PET_NOT_FOSTERED': '这只伙伴不在寄养仓库中',
    // ---------- P2 进化（rpc_pet_evolve，feature_pet_p2_rpcs_20260923.sql §3） ----------
    'PET_EVOLVE_CHAIN_MISSING': '这只伙伴还没有进化路线，暂时不能进化',
    'PET_EVOLVE_AT_END': '它已经是最终形态啦',
    'PET_EVOLVE_PICK_REQUIRED': '这一步有多个方向可选，请重新选择目标形态',
    'PET_EVOLVE_STAGE_MISSING': '进化阶段配置缺失，请联系管理员',
    'PET_EVOLVE_SPECIES_DISABLED': '这个形态暂未开放，请先选择其他方向',
    'PET_EVOLVE_COND_NOT_MET': '进化条件还没满足，再积累一会儿',
    'PET_EVOLVE_COND_INVALID': '进化条件配置有误，请联系管理员',
    // ---------- P2 等待孵化与加速（§2） ----------
    'PET_EGG_ALREADY_HATCHED': '这枚蛋已经孵化过了',
    'PET_EGG_NOT_WAITING': '这枚蛋还没开始孵化，先点「孵化」计时',
    'PET_EGG_NOT_READY': '蛋还没成熟，再等一会儿或加速',
    'PET_ACCEL_ALREADY_READY': '这枚蛋已经可以领取了',
    // ---------- P2 功能解锁（§4） ----------
    'PET_FEATURE_ITEM_INVALID': '该道具不能用于开通功能',
    'PET_FEATURE_ALREADY': '这个功能已经开通了',
    // ---------- P2 繁育（§5）：CD/亲密度阈值均为后台配置，文案不写具体数值 ----------
    'PET_BREED_INVALID_PET': '请选择两只养育中的伙伴结配',
    'PET_BREED_NOT_UNLOCKED': '繁育还没开通，可在商城购买「繁育巢穴」',
    'PET_BREED_BUSY': '这只伙伴正忙着（繁育/历险/寄养），先处理完再来',
    'PET_BREED_INTIMACY_LOW': '亲密度还不够，多陪陪它们再结配',
    'PET_BREED_NOT_SAME_FAMILY': '只有同系别的伙伴才能结配',
    'PET_BREED_SAME_GENDER': '需要一公一母才能结配',
    'PET_BREED_COOLDOWN': '刚繁育过，等它们恢复一下再来',
    'PET_BREED_LOG_NOT_FOUND': '未找到这条繁育记录',
    'PET_BREED_ALREADY_CLAIMED': '这枚蛋已经领取过了',
    'PET_BREED_NOT_READY': '宝宝还没足月，再等等',
    'PET_BREED_EGG_ITEM_MISSING': '繁育蛋配置缺失，请联系管理员',
    // ---------- P2 成就（§6） ----------
    'PET_ACH_NOT_FOUND': '该成就暂不可领取，请稍后重试',
    'PET_ACH_ALREADY_CLAIMED': '这份奖励已经领过啦',
    'PET_ACH_NOT_DONE': '这个成就还没达成',
    // ---------- P2 周任务（§7） ----------
    'PET_WEEKLY_NOT_FOUND': '未找到本周任务，请稍后刷新',
    'PET_WEEKLY_ALREADY_CLAIMED': '本周奖励已经领过啦',
    'PET_WEEKLY_NOT_DONE': '本周任务还没完成',
  };
  if (map.containsKey(code)) return map[code]!;
  if (code.length <= 40) return code;
  return '操作失败，请稍后重试';
}
