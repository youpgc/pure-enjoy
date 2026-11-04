import '../models/pet_event_models.dart';
import 'pet_rpc.dart';
import 'pet_service.dart';

/// 宠物 RPC 场景/事件域（场景购买与启用/随机事件/时间线）
///
/// 与 [PetRpc] 分文件的原因：主类超 500 行硬底线，按域拆分；
/// 调用口径完全一致——复用 [PetRpc.callRpc]（错误原文 + raw jsonb）。
/// 自 pet_rpc.dart 拆出，调用方由 PetRpc.xxx 改为 PetRpcScene.xxx。
class PetRpcScene {
  PetRpcScene._();

  /// RPC 调用口径（复用 [PetRpc.callRpc]：错误原文 + raw jsonb）
  static Future<(Map<String, dynamic>?, String?)> _call(
    String fn,
    Map<String, dynamic> params,
    String note,
  ) =>
      PetRpc.callRpc(fn, params, note);


  /// 场景主题目录 + 拥有态 + 当前激活（§11.1 背景主题购买替换）
  static Future<(Map<String, dynamic>?, String?)> fetchScenes() async {
    return _call('rpc_pet_scenes', {}, 'rpc_pet_scenes 场景目录');
  }

  /// 购买场景主题（扣金+解锁+自动激活，三合一事务）
  static Future<(Map<String, dynamic>?, String?)> purchaseScene(String sceneCode) async {
    final (data, err) = await _call('rpc_pet_scene_purchase', {
      'p_scene_code': sceneCode,
    }, 'rpc_pet_scene_purchase 购买主题');
    if (err == null) await PetService.instance.invalidateSummary();
    return (data, err);
  }

  /// 切换场景（默认或已拥有方可激活）
  static Future<(Map<String, dynamic>?, String?)> activateScene(String sceneCode) async {
    final (data, err) = await _call('rpc_pet_scene_activate', {
      'p_scene_code': sceneCode,
    }, 'rpc_pet_scene_activate 切换主题');
    return (data, err);
  }

  /// 成长时间线（只读，最近 pLimit 条倒序）
  static Future<(Map<String, dynamic>?, String?)> fetchTimeline(String petId, {int limit = 100}) async {
    return _call('rpc_pet_timeline', {
      'p_pet_id': petId,
      'p_limit': limit,
    }, 'rpc_pet_timeline 成长时间线');
  }

    /// 随机事件抽取（§3.6）：服务端掷概率 + 加权抽当日未触发事件。
  /// 未命中返回 (null, null)——fired=false 属正常业务态，不是错误。
  /// roll 不失效 summary（未改任何数值，配额与流水都在服务端）。
  static Future<(PetEventModel?, String?)> eventRoll(String context) async {
    final (data, err) = await _call('rpc_pet_event_roll', {
      'p_context': context,
    }, 'rpc_pet_event_roll 随机事件抽取');
    if (err != null) return (null, err);
    return (PetEventModel.fromJson(data ?? const {}), null);
  }

  /// 随机事件选择结算。作用对象传当前查看的在养宠物（多宠用户自主决定加成落点）。
  /// 成功后失效 summary（心情/经验/亲密/饱食/金币可能变化）。
  static Future<(PetEventChooseResultModel?, String?)> eventChoose(
    String eventId,
    int optionIndex,
    String petId,
  ) async {
    final (data, err) = await _call('rpc_pet_event_choose', {
      'p_event_id': eventId,
      'p_option_index': optionIndex,
      'p_pet_id': petId,
    }, 'rpc_pet_event_choose 随机事件选择');
    if (err != null) return (null, err);
    await PetService.instance.invalidateSummary();
    return (
      PetEventChooseResultModel.fromJson(data ?? const {}),
      null,
    );
  }
}
