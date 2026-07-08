## Messaging layer core: the `MessagingClient` type plus its construction and
## lifecycle. The public operations (subscribe / unsubscribe / send) live in
## `messaging/api.nim`.
import results, chronos
import chronicles
import
  logos_delivery/api/messaging_client_api,
  logos_delivery/waku/waku,
  logos_delivery/messaging/delivery_service/[recv_service, send_service],
  logos_delivery/messaging/rate_limit_manager/rate_limit_manager

# Surfaces the messaging API interface (and its Message* events) to consumers.
export messaging_client_api
export rate_limit_manager

type
  MessagingClientConf* = object ## Per-layer config object for the messaging API.
    useP2PReliability*: bool
    rateLimit*: RateLimitConfig

  MessagingClient* = ref object
    brokerCtx*: BrokerContext
    waku*: Waku ## The Waku kernel this layer drives; read by `messaging/api/*`.
    sendService*: SendService
    recvService*: RecvService
    rateLimit*: RateLimitManager
    started*: bool

proc new*(
    T: type MessagingClient, conf: MessagingClientConf, waku: Waku
): Result[T, string] =
  ## The messaging layer chains onto Waku: it drives the underlying Waku kernel
  ## for transport while exposing its own send/recv API.
  let sendService = ?SendService.new(conf.useP2PReliability, waku)
  let recvService = RecvService.new(waku)
  return ok(
    T(
      waku: waku,
      sendService: sendService,
      recvService: recvService,
      rateLimit: RateLimitManager.new(conf.rateLimit),
      brokerCtx: waku.brokerCtx,
    )
  )

proc checkApiAvailability*(self: MessagingClient): Result[void, string] =
  ## Shared guard for the api operation module.
  if self.isNil():
    return err("MessagingClient is not initialized")

  return ok()
