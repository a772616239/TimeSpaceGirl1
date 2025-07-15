// using System;
//
// using GameCore;
// using TMPro;
// using UnityEngine;
// using UnityEngine.Events;
// using UnityEngine.Purchasing;
// using UnityEngine.Purchasing.Extension;
// using UnityEngine.UI;
//
// public class IAPResult
// {
//     public bool IsSucc = false;
//     public Product product;
//     public PurchaseFailureReason failureReason;
//     public PurchaseFailureDescription failureDescription;
//
//     public PurchasedInfo ConvertToPurchasedInfo(string buykey)
//     {
//         var purchasedInfo = new PurchasedInfo();
//         purchasedInfo.Receipt=product.receipt;
//         purchasedInfo.TransactionId=product.transactionID;
//         purchasedInfo.ProductId=buykey;
//         return purchasedInfo;
//     }
// }
// public class ShopCoinIAP :BaseBehaviour
// {
//     public IStoreController m_StoreController; // The Unity Purchasing system.
//     
//     void Start()
//     {
//         InitializePurchasing();
//         // CrashlyticsMgr.Inst.ShopView("ShopView");
//     }
//     
//     void InitializePurchasing()
//     {
//         var builder = ConfigurationBuilder.Instance(StandardPurchasingModule.Instance());
//
//         //Add products that will be purchasable and indicate its type.
//         builder.AddProduct("buycoin1", ProductType.Consumable);
//         builder.AddProduct("buycoin2", ProductType.Consumable);
//         builder.AddProduct("buycoin3", ProductType.Consumable);
//         builder.AddProduct("buycoin4", ProductType.Consumable);
//         builder.AddProduct("buycoin5", ProductType.Consumable);
//         builder.AddProduct("buycoin6", ProductType.Consumable);
//
//         UnityPurchasing.Initialize(this, builder);
//     }
//
//
//     public void OnInitialized(IStoreController controller, IExtensionProvider extensions)
//     {
//         Debug.Log("In-App Purchasing successfully initialized");
//         m_StoreController = controller;
//
//     }
//
//
//     public void OnInitializeFailed(InitializationFailureReason error)
//     {
//         string errorDes = "";
//         switch (error)
//         {
//             case InitializationFailureReason.AppNotKnown:
//                 errorDes = "你的应用是否正确上传到相关发行商控制台?";
//                 break;
//             case InitializationFailureReason.PurchasingUnavailable:
//                 errorDes = "计费禁用！用户是否在设备设置中禁用了计费。";
//                 break;
//             case InitializationFailureReason.NoProductsAvailable:
//                 errorDes = "没有可供购买的产品！开发者配置错误；检查产品配置数据！";
//                 break;
//             default:
//                 errorDes = $"初始化未处理异常 {error}";
//                 break;
//         }
//         Debug.Log("In-App Purchasing OnInitializeFailed"+error+"---errorDes:"+errorDes);
//
//         OnInitializeFailed(error, null);
//     }
//
//     public void OnInitializeFailed(InitializationFailureReason error, string message)
//     {
//         var errorMessage = $"Purchasing failed to initialize. Reason: {error}.";
//
//         if (message != null)
//         {
//             errorMessage += $" More details: {message}";
//         }
//
//         // DialogFactory.ShowBannerTipByKey("NET.CFG.ERROR");
//         Debug.Log(errorMessage);
//     }
//
//     private TaskCompletionSource<IAPResult> tcs;
//     public async ETTask<IAPResult> BuyItem(string pruductid)
//     {
//         tcs  = new TaskCompletionSource<IAPResult>();
//         var product= m_StoreController.products.WithID(pruductid);
//
//         m_StoreController.InitiatePurchase(product);
//         return await tcs.Task;
//     }
//     
//     public PurchaseProcessingResult ProcessPurchase(PurchaseEventArgs args)
//     {
//         //Retrieve the purchased product
//         var product = args.purchasedProduct;
//         Log.Info($"购买成功 需要验单: {product.hasReceipt} --> {product.definition.id} --> {product.transactionID} --> receipt:{product.receipt}");
//         //Add the purchased product to the players inventory
//         Debug.Log($"Purchase Complete - Product: {product.definition.id}");
//         tcs.SetResult(new IAPResult()
//         {
//             IsSucc = true,
//             product = product,
//             
//         });
//         //We return Complete, informing IAP that the processing on our side is done and the transaction can be closed.
//         return PurchaseProcessingResult.Complete;
//     }
//
//     public void OnPurchaseFailed(Product product, PurchaseFailureReason failureReason)
//     {
//         Debug.Log($"Purchase failed - Product: '{product.definition.id}', PurchaseFailureReason: {failureReason}");
//         tcs.SetResult(new IAPResult()
//         {
//             IsSucc = false,
//             product = product,
//             failureReason = failureReason
//         });
//     }
//    
//     public void OnPurchaseFailed(Product product, PurchaseFailureDescription failureDescription)
//     {
//         Debug.Log($"Purchase failed - Product: '{product.definition.id}'," +
//             $" Purchase failure reason: {failureDescription.reason}," +
//             $" Purchase failure details: {failureDescription.message}");
//         tcs.SetResult(new IAPResult()
//         {
//             IsSucc = false,
//             product = product,
//             failureDescription = failureDescription
//         });
//     }
//
//     public override void OnDestroy()
//     {
//         base.OnDestroy();
//         UIComponent.CrtOpenView = null;
//
//         if (!DialogFactory.IsShowingList)
//         {
//             EventMsgMgr.SendEvent(_LobbyFactory.OnIsShowLobby,true);
//         }
//     }
// }