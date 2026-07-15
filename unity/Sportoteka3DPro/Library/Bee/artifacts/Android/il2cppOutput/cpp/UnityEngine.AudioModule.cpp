#include "pch-cpp.hpp"





template <typename T1>
struct VirtualActionInvoker1
{
	typedef void (*Action)(void*,T1,const RuntimeMethod*);

	static inline void Invoke (Il2CppMethodSlot slot, RuntimeObject* obj, T1 p1)
	{
		const VirtualInvokeData& invokeData = il2cpp_codegen_get_virtual_invoke_data(slot, obj);
		((Action)invokeData.methodPtr)(obj,p1,invokeData.method);
	}
};
template <typename T1>
struct GenericVirtualActionInvoker1
{
	typedef void (*Action)(void*,T1,const RuntimeMethod*);

	static inline void Invoke (const RuntimeMethod* method, RuntimeObject* obj, T1 p1)
	{
		VirtualInvokeData invokeData;
		il2cpp_codegen_get_generic_virtual_invoke_data(method, obj, &invokeData);
		((Action)invokeData.methodPtr)(obj,p1,invokeData.method);
	}
};
template <typename T1>
struct InterfaceActionInvoker1
{
	typedef void (*Action)(void*,T1,const RuntimeMethod*);

	static inline void Invoke (Il2CppMethodSlot slot, RuntimeClass* declaringInterface, RuntimeObject* obj, T1 p1)
	{
		const VirtualInvokeData& invokeData = il2cpp_codegen_get_interface_invoke_data(slot, obj, declaringInterface);
		((Action)invokeData.methodPtr)(obj,p1,invokeData.method);
	}
};
template <typename R>
struct InterfaceFuncInvoker0
{
	typedef R (*Func)(void*,const RuntimeMethod*);

	static inline R Invoke (Il2CppMethodSlot slot, RuntimeClass* declaringInterface, RuntimeObject* obj)
	{
		const VirtualInvokeData& invokeData = il2cpp_codegen_get_interface_invoke_data(slot, obj, declaringInterface);
		return ((Func)invokeData.methodPtr)(obj,invokeData.method);
	}
};
template <typename R, typename T1, typename T2, typename T3>
struct InterfaceFuncInvoker3
{
	typedef R (*Func)(void*,T1,T2,T3,const RuntimeMethod*);

	static inline R Invoke (Il2CppMethodSlot slot, RuntimeClass* declaringInterface, RuntimeObject* obj, T1 p1, T2 p2, T3 p3)
	{
		const VirtualInvokeData& invokeData = il2cpp_codegen_get_interface_invoke_data(slot, obj, declaringInterface);
		return ((Func)invokeData.methodPtr)(obj,p1,p2,p3,invokeData.method);
	}
};
template <typename T1>
struct GenericInterfaceActionInvoker1
{
	typedef void (*Action)(void*,T1,const RuntimeMethod*);

	static inline void Invoke (const RuntimeMethod* method, RuntimeObject* obj, T1 p1)
	{
		VirtualInvokeData invokeData;
		il2cpp_codegen_get_generic_interface_invoke_data(method, obj, &invokeData);
		((Action)invokeData.methodPtr)(obj,p1,invokeData.method);
	}
};

struct Action_1_t10DCB0C07D0D3C565CEACADC80D1152B35A45F6C;
struct Action_1_t923A20D1D4F6B55B2ED5AE21B90F1A0CE0450D99;
struct method_t81535E3A9A313D01BC63006B5A25610B21847FBD;
struct method_tF13E4C1D2723EFA21A0B8D9A21D42FE0334B238E;
struct CharU5BU5D_t799905CF001DD5F13F7DBB310181FC4D8B7D0AAB;
struct DelegateU5BU5D_tC5AB7E8F745616680F337909D3A8E6C722CDF771;
struct IntPtrU5BU5D_tFD177F8C806A6921AD7150264CCC62FA00CAD832;
struct ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A;
struct SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C;
struct StackTraceU5BU5D_t32FBCB20930EAF5BAE3F450FF75228E5450DA0DF;
struct WebCamDeviceU5BU5D_tA5B1352BDE6FE233B66C3ABF96E00EB3215629F5;
struct Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07;
struct Attribute_tFDA8EFEFB0711976D22474794576DAF28F7440AA;
struct AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20;
struct AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2;
struct ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67;
struct Delegate_t;
struct DelegateData_t9B286B493293CD2D23A5B2B5EF0E5B1324C2B77E;
struct EmbeddedAttribute_tDFF02CAA8432C01BCA04CBAB5F8600F62813A849;
struct IAudioGenerator_tD9DD08E5891ADC8BBD55CA6E1F00C0EED5C816DA;
struct IDictionary_t6D03155AF1FA9083817AA5B6AD7DEEACC26AB220;
struct InvalidOperationException_t5DDE4D49B7405FAAB1E4576F4715A42A3FAD4BAB;
struct MethodInfo_t;
struct NotSupportedException_t1429765983D409BD2986508963C98D214E4EBF4A;
struct Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C;
struct ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085;
struct RefSafetyRulesAttribute_tBA6EA196F2B7FCDEDF930A6583457BBFB7B4DDF2;
struct SafeSerializationManager_tCBB85B95DFD1634237140CD892E82D06ECB3F5E6;
struct String_t;
struct Void_t4861ACF8F4594C3437BB48B6E56783494B843915;
struct PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E;
struct PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072;
struct SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30;
struct AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177;
struct Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060;

IL2CPP_EXTERN_C Il2CppSequencePoint g_sequencePointsUnityEngine_AudioModule[];
IL2CPP_EXTERN_C Il2CppSequencePoint g_sequencePointsUnityEngine_CoreModule[];
IL2CPP_EXTERN_C RuntimeClass* AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C RuntimeClass* Debug_t8394C7EEAECA3689C2C9B9DE9C7166D73596276F_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C RuntimeClass* DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C RuntimeClass* GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C RuntimeClass* Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C RuntimeClass* IAudioGenerator_tD9DD08E5891ADC8BBD55CA6E1F00C0EED5C816DA_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C RuntimeClass* ICapabilities_tF49934ED8BF0930F82A0A54F794949FB61194793_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C RuntimeClass* InvalidOperationException_t5DDE4D49B7405FAAB1E4576F4715A42A3FAD4BAB_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C RuntimeClass* Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C RuntimeClass* NotSupportedException_t1429765983D409BD2986508963C98D214E4EBF4A_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C RuntimeClass* Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C RuntimeClass* ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C RuntimeClass* ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A_il2cpp_TypeInfo_var;
IL2CPP_EXTERN_C String_t* _stringLiteral0D4DFFEDA70FA6D865B68C20C1F40F10FC31B6DD;
IL2CPP_EXTERN_C String_t* _stringLiteral23ABA34B45DF51C7D9C0E116AA6FDA4749E8C618;
IL2CPP_EXTERN_C String_t* _stringLiteral5A10D0C56FEA8FB8816E3E1F6F88D55578F844F7;
IL2CPP_EXTERN_C String_t* _stringLiteral5C2C12AF4EFFBF824B747CFFBFC316CAE24077D1;
IL2CPP_EXTERN_C String_t* _stringLiteral897119E4E307249E22F47D5E55BF736C2DDC58CE;
IL2CPP_EXTERN_C String_t* _stringLiteralA26BD5C8DBC6B4716A120AC6F43A2DFD1452A36B;
IL2CPP_EXTERN_C String_t* _stringLiteralC767BA736F2BEEB0EC1BA27ABE77214EC763C9B6;
IL2CPP_EXTERN_C String_t* _stringLiteralEE560D196E71D95F90A39910549B06428576F27C;
IL2CPP_EXTERN_C const RuntimeMethod* AudioClipPlayable_Equals_m9C1C75ACBB74FE06AD02BE4643F6EB39413EFF83_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioClipPlayable_GetHandle_mEA1D664328FF9B08E4F7D5EBCD4B51A754D97C44_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioClip_CheckIsNotPersistent_m9792AEB282CC66210DDB73702C33EF5FC001313C_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioClip_CreateInstance_m00611E45FCDB4A13BC7A07018E41DFFB4C6DAB73_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioClip_InvokePCMReaderCallback_Internal_m766E5705AB5AE16F5F142867CC3758ABE4BF462C_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioClip_InvokePCMSetPositionCallback_Internal_m986EF703B7DDE42343730DE93A095D05B9F4DBB8_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioClip_IsLegacyFormat_m3DB8BD55B7C96596B031D7E2AE5B430C00CE4D58_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioClip_UnityEngine_Audio_GeneratorInstance_ICapabilities_get_isFinite_m20E61329E86505BA44C480115CD9A403FC63308C_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioClip_UnityEngine_Audio_GeneratorInstance_ICapabilities_get_isRealtime_mAC78FD95FB9998B38D0E50C2462DC9D9147FEAA4_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioClip_UnityEngine_Audio_GeneratorInstance_ICapabilities_get_length_mCA231C69B56E93689C2B45DCE2C3F0AD45CF541B_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioClip_get_frequency_m6647E10F4B2B1335187B0066E82468CCCF19647B_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioClip_get_samples_mDEA01CA75E7DEA0F8D480E4AF97FB96085BCF38E_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioFormat_get_audioConfiguration_m769CBA67D62C1D12FBE6C55DC2429D62BA135D43_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioMixerPlayable_Equals_mDFB945EB48199A338BAD00D40FB8EEC34CF64D57_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioMixerPlayable_GetHandle_m6C182D9794E901D123223BB57738A302BEAB41FD_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioSampleProvider_InvokeSampleFramesAvailable_mEB16F7230AB65A3576BF053AC5719F8E134FBCD4_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioSampleProvider_InvokeSampleFramesOverflow_m66593173A527981F5EB2A5EF77B0C9119DAB5E15_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioSettings_InvokeOnAudioConfigurationChanged_m8273D3AEB24F4C3E374238B6F699BE6696808E85_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioSettings_InvokeOnAudioSystemShuttingDown_m1B9895D60B3267EBDEC69B9169730DBAD8325E90_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* AudioSettings_InvokeOnAudioSystemStartedUp_m7FE042936237E5BDCB20299D8C4CF583B661468C_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Configuration_FramesAndSampleRateToDiscreteTimeTicks_mD8442DC6E7541DA57E38136E474B09FA2A8CC066_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Configuration_get_isRealtime_m99E988C200947A8277C144A84CB1755B5A0C2D78_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Configuration_get_length_mB699EC1CF6B8A0955A60B55ABB22AD00A3F6BC3B_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* ControlContext_CleanupHeader_mC560997117E3E82A193438753C1020A76A208F5E_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* ControlContext_Exists_mEEB0CCB244CABE9EAD81EBC5E54CB6B50E18FA0F_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* ControlContext_GetConfiguration_m5EF5175CD07C7E1661F6AC36ECEA52A293DB0249_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* ControlContext__ctor_mFFC3A14E72F61DACB51F4F771FAE8416702023B6_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* ControlContext_get_Header_m48ED40585DBA374B2750157BEFD1A0DC92B654E2_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* DiscreteTime_FromTicks_m0AF37F302A6729B9C86ACBBBF3CA26471DF131BC_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* DiscreteTime__ctor_m5DF0E73E12BD613EE452B88012E01EF83E70383E_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* DiscreteTime_op_Inequality_m4C12F6A54E5C6E8BAC45A3903E6C2A3127C6063C_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* EmbeddedAttribute__ctor_m435F561C10EB1CFADACDF6202954D45787911FDE_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* GCHandle_get_IsAllocated_m241908103D8D867E11CCAB73C918729825E86843_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* GeneratorInstance_Equals_m1FEFD7862F181D69396710522A061AA1A5189FE1_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* GeneratorInstance_Equals_m7412F772B53B5052FF5070FB2BB2099A93270206_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* GeneratorInstance_GetHashCode_mBF9BB29BE3D212AAAEF53A02346FED4B0435C7D2_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* GeneratorInstance__ctor_m918C508DE9944B098D0305A557F6BDC7227C3518_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* GeneratorInstance_op_Implicit_mB7A6E46130D3BAB42E00F4DD08155EF286A16167_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Handle_CheckValidOrThrow_mA6C3BAA711CDA462A6A2653A1A2D04CE2AECD3C3_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Handle_Equals_m5D8356E5FCA91FFFEACC910C738C37690EBA2E64_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Handle_Equals_mDE217E745B1016A74BCE82848675ED913B391B8F_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Handle_GetHashCode_m8DD5E2EE5197C1FF37CD2CF3B4FD892A9E299DFE_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Handle_get_AtomicNode_m3D7AF7852BDF5999877F8F973FDF8724974B0A50_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Handle_get_ValidAndNotDisposed_m1097F1E099632EDF74478AD5B74978BD3FAEF145_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* IntPtr_op_Equality_m7D9CDCDE9DC2A0C2C614633F4921E90187FAB271_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* IntPtr_op_Inequality_m90EFC9C4CAD9A33E309F2DDF98EE4E1DD253637B_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* MarshalledUnityObject_MarshalNotNull_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_mC3A4EC248FAFFBF10CD74B1E57A203FE7D9E01F5_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* MarshalledUnityObject_Marshal_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_m4CF5833467B7EAC854506E5E808202FABD1F15CC_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Mobile_InvokeIsStopAudioOutputOnMuteEnabled_m854CB455C7BE7ADC06BABCB9AA24F60309AE7ED1_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Mobile_InvokeOnMuteStateChanged_mE5242862F948BA9FBB013A2B45F645B6A21E6198_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Mobile_StartAudioOutput_m731D1EEEE7A0D56BAADD571BA0FCAC13FB071223_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Mobile_StopAudioOutput_m10B8CEF668EE4967D0AD1D6741B6A37540C28A46_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Mobile_get_muteState_m64C1E8C61537317A7F153E1A72F7D39D85DA684D_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Mobile_get_stopAudioOutputOnMute_m43EC82258D38C418353DFE19F32B51B64B18DCCA_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Mobile_set_muteState_m7C9A464BCA3762330E18CCAD79AF6C47B863CA02_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Nullable_1_GetValueOrDefault_m5879DF28E8CBC03BD7B2F3A7B383BB0068DE64DC_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Nullable_1__ctor_mA3535F58A54E060F67F4FFB3A5974A10D6444604_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Nullable_1_get_HasValue_m0A28F36C93C270B2B16241740BA7B9CFE0166F7A_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Nullable_1_get_HasValue_m2C09C399366A16930BBC996441FE7CED2907D3D0_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* Nullable_1_get_Value_m32D74DBCABD51FD09C2289F4AB5813C51FD97782_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* ProcessorInstance_Equals_m4873E7D141484FCADC7F0F9C64542D57E0D02398_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* ProcessorInstance_Equals_mFE0F0DA5B311AD6D34EABD73F61C4AE3014084ED_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* ProcessorInstance_GetHashCode_m607D39F5BA947B94238348CF61431A9D8049F9B0_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* ProcessorInstance__ctor_m3E0B9039361DE404D8DF604C8D6E324B2F6CC36B_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* RefSafetyRulesAttribute__ctor_m35BCB21D10EE61C71ED4F6CA05DE681A759393A6_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* SampleProviderBindings_CreateGeneratorHeader_m431C7ACC029F1B61B5C7C81F894FED9AA6C5F640_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* ScriptableGeneratorBindings_InstantiateGeneratorFromObject_m627DB7836271F2551E83B21A49E39952BA58D7B3_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* ScriptableProcessorBindings_CheckProcessorExistsInternal_mF6C33BA9D06B46EAAA47D05E74BA20CC604141A6_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* ScriptableProcessorBindings_CheckProcessorExists_mCA17BD1A2B9E776034C7B312CA810B3B739AA04E_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeMethod* WebCamDevice_ReconstructArrayElementRaw_m6B898336095C8CFC6B06E150C17D25621A914CC7_RuntimeMethod_var;
IL2CPP_EXTERN_C const RuntimeType* AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* AudioConfigurationU2A_t8DA90320E7ADA7D88875EF03803878B80747E4F4_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* ControlHeaderU2A_t829B34D8DC0A755115481A118D668FFD483EEF97_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* CreationParameters_tC3AF64A7D0E7DAF87A587B34097DF91B377A9BD7_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* GCHandle_tC44F6F72EE68BD4CFABA24309DA7A179D41127DC_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* GeneratorHeaderU2A_t02B3CDAA7BFFE71942313A5F2CCABF2711EDA5BA_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* IAudioGenerator_tD9DD08E5891ADC8BBD55CA6E1F00C0EED5C816DA_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* Nullable_1_t8743998EB2E7DB936C93772849EF306FBD5C5EE5_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35_0_0_0_var;
IL2CPP_EXTERN_C const RuntimeType* WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_0_0_0_var;
struct Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060;;
struct Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_com;
struct Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_com;;
struct Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_pinvoke;
struct Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_pinvoke;;
struct Delegate_t_marshaled_com;
struct Delegate_t_marshaled_pinvoke;
struct Exception_t_marshaled_com;
struct Exception_t_marshaled_pinvoke;
struct Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525;

struct DelegateU5BU5D_tC5AB7E8F745616680F337909D3A8E6C722CDF771;
struct ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A;
struct SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C;
struct WebCamDeviceU5BU5D_tA5B1352BDE6FE233B66C3ABF96E00EB3215629F5;

IL2CPP_EXTERN_C_BEGIN
IL2CPP_EXTERN_C_END

#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
struct U3CModuleU3E_t462BCCFB9B78348533823E0754F65F52A5348F89 
{
};
struct Attribute_tFDA8EFEFB0711976D22474794576DAF28F7440AA  : public RuntimeObject
{
};
struct AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2  : public RuntimeObject
{
	SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* ___sampleFramesAvailable;
	SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* ___sampleFramesOverflow;
};
struct AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD  : public RuntimeObject
{
};
struct SampleProviderBindings_tA4CA9B6AE79C693D44C7DA09A24696C4FBBB08B3  : public RuntimeObject
{
};
struct ScriptableGeneratorBindings_tB9FD8D788D5EDF66E708E851437C25CA5ECA514D  : public RuntimeObject
{
};
struct ScriptableProcessorBindings_t89BE2B31C684864ED0E1E5D6F978928182C9E9E8  : public RuntimeObject
{
};
struct String_t  : public RuntimeObject
{
	int32_t ____stringLength;
	Il2CppChar ____firstChar;
};
struct ValueType_t6D9B272BD21782F0A9A14F2E41F85A50E97A986F  : public RuntimeObject
{
};
struct ValueType_t6D9B272BD21782F0A9A14F2E41F85A50E97A986F_marshaled_pinvoke
{
};
struct ValueType_t6D9B272BD21782F0A9A14F2E41F85A50E97A986F_marshaled_com
{
};
struct Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD  : public RuntimeObject
{
};
typedef Il2CppFullySharedGenericStruct Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339;
struct Boolean_t09A6377A54BE2F9E6985A8149F19234FD7DDFE22 
{
	bool ___m_value;
};
struct DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E 
{
	int64_t ___Value;
};
struct EmbeddedAttribute_tDFF02CAA8432C01BCA04CBAB5F8600F62813A849  : public Attribute_tFDA8EFEFB0711976D22474794576DAF28F7440AA
{
};
struct Enum_t2A1A94B24E3B776EEF4E5E485E290BB9D4D072E2  : public ValueType_t6D9B272BD21782F0A9A14F2E41F85A50E97A986F
{
};
struct Enum_t2A1A94B24E3B776EEF4E5E485E290BB9D4D072E2_marshaled_pinvoke
{
};
struct Enum_t2A1A94B24E3B776EEF4E5E485E290BB9D4D072E2_marshaled_com
{
};
struct Int32_t680FF22E76F6EFAD4375103CBBFFA0421349384C 
{
	int32_t ___m_value;
};
struct Int64_t092CFB123BE63C28ACDAF65C68F21A526050DBA3 
{
	int64_t ___m_value;
};
struct IntPtr_t 
{
	void* ___m_value;
};
struct RefSafetyRulesAttribute_tBA6EA196F2B7FCDEDF930A6583457BBFB7B4DDF2  : public Attribute_tFDA8EFEFB0711976D22474794576DAF28F7440AA
{
	int32_t ___Version;
};
struct RefreshRate_t44FF0D3F256477CC8AB97FA49D08B636AFB4F68F 
{
	uint32_t ___numerator;
	uint32_t ___denominator;
};
struct Single_t4530F2FF86FCB0DC29F35385CA1BD21BE294761C 
{
	float ___m_value;
};
struct UInt32_t1833D51FFA667B18A5AA4B8D34DE284F8495D29B 
{
	uint32_t ___m_value;
};
struct Void_t4861ACF8F4594C3437BB48B6E56783494B843915 
{
	union
	{
		struct
		{
		};
		uint8_t Void_t4861ACF8F4594C3437BB48B6E56783494B843915__padding[1];
	};
};
struct Properties_tA0A739E222CC4DF46C8E1F08B908950539845092 
{
	uint8_t ___m_Reserved;
};
struct Node_tE9DD997AC2A1CDC0DF9579D3B88467E7F42142C8 
{
	void* ___Next;
	int32_t ___Id;
	int32_t ___Version;
	int32_t ___AllocationFlags;
};
struct Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 
{
	bool ___hasValue;
	DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E ___value;
};
struct AudioSpeakerMode_tD681BDF379A4FB499C5562BF3F97AB93B4E540ED 
{
	int32_t ___value__;
};
struct ControlFunction_tF56532B76DBED412D41D1DC56F7002D533A56F87 
{
	uint32_t ___value__;
};
struct Delegate_t  : public RuntimeObject
{
	intptr_t ___method_ptr;
	intptr_t ___invoke_impl;
	RuntimeObject* ___m_target;
	intptr_t ___method;
	intptr_t ___delegate_trampoline;
	intptr_t ___extra_arg;
	intptr_t ___method_code;
	intptr_t ___interp_method;
	intptr_t ___interp_invoke_impl;
	MethodInfo_t* ___method_info;
	MethodInfo_t* ___original_method_info;
	DelegateData_t9B286B493293CD2D23A5B2B5EF0E5B1324C2B77E* ___data;
	bool ___method_is_virtual;
};
struct Delegate_t_marshaled_pinvoke
{
	intptr_t ___method_ptr;
	intptr_t ___invoke_impl;
	Il2CppIUnknown* ___m_target;
	intptr_t ___method;
	intptr_t ___delegate_trampoline;
	intptr_t ___extra_arg;
	intptr_t ___method_code;
	intptr_t ___interp_method;
	intptr_t ___interp_invoke_impl;
	MethodInfo_t* ___method_info;
	MethodInfo_t* ___original_method_info;
	DelegateData_t9B286B493293CD2D23A5B2B5EF0E5B1324C2B77E* ___data;
	int32_t ___method_is_virtual;
};
struct Delegate_t_marshaled_com
{
	intptr_t ___method_ptr;
	intptr_t ___invoke_impl;
	Il2CppIUnknown* ___m_target;
	intptr_t ___method;
	intptr_t ___delegate_trampoline;
	intptr_t ___extra_arg;
	intptr_t ___method_code;
	intptr_t ___interp_method;
	intptr_t ___interp_invoke_impl;
	MethodInfo_t* ___method_info;
	MethodInfo_t* ___original_method_info;
	DelegateData_t9B286B493293CD2D23A5B2B5EF0E5B1324C2B77E* ___data;
	int32_t ___method_is_virtual;
};
struct Exception_t  : public RuntimeObject
{
	String_t* ____className;
	String_t* ____message;
	RuntimeObject* ____data;
	Exception_t* ____innerException;
	String_t* ____helpURL;
	RuntimeObject* ____stackTrace;
	String_t* ____stackTraceString;
	String_t* ____remoteStackTraceString;
	int32_t ____remoteStackIndex;
	RuntimeObject* ____dynamicMethods;
	int32_t ____HResult;
	String_t* ____source;
	SafeSerializationManager_tCBB85B95DFD1634237140CD892E82D06ECB3F5E6* ____safeSerializationManager;
	StackTraceU5BU5D_t32FBCB20930EAF5BAE3F450FF75228E5450DA0DF* ___captured_traces;
	IntPtrU5BU5D_tFD177F8C806A6921AD7150264CCC62FA00CAD832* ___native_trace_ips;
	int32_t ___caught_in_unmanaged;
};
struct Exception_t_marshaled_pinvoke
{
	char* ____className;
	char* ____message;
	RuntimeObject* ____data;
	Exception_t_marshaled_pinvoke* ____innerException;
	char* ____helpURL;
	Il2CppIUnknown* ____stackTrace;
	char* ____stackTraceString;
	char* ____remoteStackTraceString;
	int32_t ____remoteStackIndex;
	Il2CppIUnknown* ____dynamicMethods;
	int32_t ____HResult;
	char* ____source;
	SafeSerializationManager_tCBB85B95DFD1634237140CD892E82D06ECB3F5E6* ____safeSerializationManager;
	StackTraceU5BU5D_t32FBCB20930EAF5BAE3F450FF75228E5450DA0DF* ___captured_traces;
	Il2CppSafeArray* ___native_trace_ips;
	int32_t ___caught_in_unmanaged;
};
struct Exception_t_marshaled_com
{
	Il2CppChar* ____className;
	Il2CppChar* ____message;
	RuntimeObject* ____data;
	Exception_t_marshaled_com* ____innerException;
	Il2CppChar* ____helpURL;
	Il2CppIUnknown* ____stackTrace;
	Il2CppChar* ____stackTraceString;
	Il2CppChar* ____remoteStackTraceString;
	int32_t ____remoteStackIndex;
	Il2CppIUnknown* ____dynamicMethods;
	int32_t ____HResult;
	Il2CppChar* ____source;
	SafeSerializationManager_tCBB85B95DFD1634237140CD892E82D06ECB3F5E6* ____safeSerializationManager;
	StackTraceU5BU5D_t32FBCB20930EAF5BAE3F450FF75228E5450DA0DF* ___captured_traces;
	Il2CppSafeArray* ___native_trace_ips;
	int32_t ___caught_in_unmanaged;
};
struct GCHandle_tC44F6F72EE68BD4CFABA24309DA7A179D41127DC 
{
	intptr_t ___handle;
};
struct Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 
{
	intptr_t ___m_Node;
	int32_t ___Version;
};
struct Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C  : public RuntimeObject
{
	intptr_t ___m_CachedPtr;
};
struct Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C_marshaled_pinvoke
{
	intptr_t ___m_CachedPtr;
};
struct Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C_marshaled_com
{
	intptr_t ___m_CachedPtr;
};
struct PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 
{
	intptr_t ___m_Handle;
	uint32_t ___m_Version;
};
struct PlayableOutputHandle_tEB217645A8C0356A3AC6F964F283003B9740E883 
{
	intptr_t ___m_Handle;
	uint32_t ___m_Version;
};
struct ProcessorFunction_t94187A2444D8312007E01AC295FBB4EFF25E4718 
{
	uint32_t ___value__;
};
struct Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525 
{
	int32_t ___m_Width;
	int32_t ___m_Height;
	RefreshRate_t44FF0D3F256477CC8AB97FA49D08B636AFB4F68F ___m_RefreshRate;
};
struct WebCamKind_t6E6C1B17D52A297F99D6A758D43B6D90D3287D5C 
{
	int32_t ___value__;
};
struct Message_tBD40926CA51B245E5907EA3415980470455D8945 
{
	int64_t ___TypeHash;
	void* ___Data;
	intptr_t ___ManagedHandle;
};
struct UpdateSetting_tA679554B453B4685917A94E3D213100F94791EEE 
{
	int32_t ___value__;
};
struct AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0 
{
	PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 ___m_Handle;
};
struct AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D 
{
	int32_t ___speakerMode;
	int32_t ___dspBufferSize;
	int32_t ___sampleRate;
	int32_t ___numRealVoices;
	int32_t ___numVirtualVoices;
};
struct AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C 
{
	PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 ___m_Handle;
};
struct AudioPlayableOutput_tC3DFF8095F429D90129A367EAB98A24F6D6ADF20 
{
	PlayableOutputHandle_tEB217645A8C0356A3AC6F964F283003B9740E883 ___m_Handle;
};
struct AudioResource_t35B84706031E4F08C928B1640B804839F4B6500A  : public Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C
{
};
struct Component_t39FBE53E5EFCF4409111FB22C15FF73717632EC3  : public Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C
{
};
struct ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243 
{
	ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* ___m_Header;
	Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___m_Handle;
};
struct ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67 
{
	Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___Handle;
	intptr_t ___ManagedTransport;
};
struct MulticastDelegate_t  : public Delegate_t
{
	DelegateU5BU5D_tC5AB7E8F745616680F337909D3A8E6C722CDF771* ___delegates;
};
struct MulticastDelegate_t_marshaled_pinvoke : public Delegate_t_marshaled_pinvoke
{
	Delegate_t_marshaled_pinvoke** ___delegates;
};
struct MulticastDelegate_t_marshaled_com : public Delegate_t_marshaled_com
{
	Delegate_t_marshaled_com** ___delegates;
};
struct ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085 
{
	void* ___m_Control;
	Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___DualThreadHandle;
	void* ___NativeProcessorFunction;
	void* ___NativeControlFunction;
	intptr_t ___ProcessorReflectionData;
	intptr_t ___ControlReflectionData;
};
struct ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 
{
	Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___Handle;
	ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085* ___Header;
};
struct SystemException_tCC48D868298F4C0705279823E34B00F4FBDB7295  : public Exception_t
{
};
struct WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C 
{
	String_t* ___m_Name;
	String_t* ___m_DepthCameraName;
	int32_t ___m_Flags;
	int32_t ___m_Kind;
	ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A* ___m_Resolutions;
};
struct WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshaled_pinvoke
{
	char* ___m_Name;
	char* ___m_DepthCameraName;
	int32_t ___m_Flags;
	int32_t ___m_Kind;
	Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525* ___m_Resolutions;
};
struct WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshaled_com
{
	Il2CppChar* ___m_Name;
	Il2CppChar* ___m_DepthCameraName;
	int32_t ___m_Flags;
	int32_t ___m_Kind;
	Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525* ___m_Resolutions;
};
struct Setup_t24BE50E09A2A2C409ED7EC3BCEB0B8ACD458A503 
{
	int32_t ___speakerMode;
	int32_t ___sampleRate;
};
struct CreationParameters_tC3AF64A7D0E7DAF87A587B34097DF91B377A9BD7 
{
	int32_t ___U3CcontrolUpdateSettingU3Ek__BackingField;
	int32_t ___U3CrealtimeUpdateSettingU3Ek__BackingField;
};
struct Action_1_t10DCB0C07D0D3C565CEACADC80D1152B35A45F6C  : public MulticastDelegate_t
{
};
struct Action_1_t923A20D1D4F6B55B2ED5AE21B90F1A0CE0450D99  : public MulticastDelegate_t
{
};
struct Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07  : public MulticastDelegate_t
{
};
struct AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20  : public AudioResource_t35B84706031E4F08C928B1640B804839F4B6500A
{
	PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E* ___m_PCMReaderCallback;
	PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072* ___m_PCMSetPositionCallback;
};
struct AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D 
{
	AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D ___m_Config;
};
struct Behaviour_t01970CFBBA658497AE30F311C447DB0440BAB7FA  : public Component_t39FBE53E5EFCF4409111FB22C15FF73717632EC3
{
};
struct GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 
{
	ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 ___m_ProcessorInstance;
};
struct InvalidOperationException_t5DDE4D49B7405FAAB1E4576F4715A42A3FAD4BAB  : public SystemException_tCC48D868298F4C0705279823E34B00F4FBDB7295
{
};
struct NotSupportedException_t1429765983D409BD2986508963C98D214E4EBF4A  : public SystemException_tCC48D868298F4C0705279823E34B00F4FBDB7295
{
};
struct PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E  : public MulticastDelegate_t
{
};
struct PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072  : public MulticastDelegate_t
{
};
struct SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30  : public MulticastDelegate_t
{
};
struct AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177  : public MulticastDelegate_t
{
};
struct Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 
{
	Setup_t24BE50E09A2A2C409ED7EC3BCEB0B8ACD458A503 ___Setup;
	Properties_tA0A739E222CC4DF46C8E1F08B908950539845092 ___Properties;
	DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E ___ReportedLength;
	bool ___IsFinite;
	bool ___IsRealtime;
	bool ___HasKnownLength;
};
struct Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_pinvoke
{
	Setup_t24BE50E09A2A2C409ED7EC3BCEB0B8ACD458A503 ___Setup;
	Properties_tA0A739E222CC4DF46C8E1F08B908950539845092 ___Properties;
	DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E ___ReportedLength;
	int32_t ___IsFinite;
	int32_t ___IsRealtime;
	int32_t ___HasKnownLength;
};
struct Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_com
{
	Setup_t24BE50E09A2A2C409ED7EC3BCEB0B8ACD458A503 ___Setup;
	Properties_tA0A739E222CC4DF46C8E1F08B908950539845092 ___Properties;
	DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E ___ReportedLength;
	int32_t ___IsFinite;
	int32_t ___IsRealtime;
	int32_t ___HasKnownLength;
};
struct Nullable_1_t8743998EB2E7DB936C93772849EF306FBD5C5EE5 
{
	bool ___hasValue;
	AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D ___value;
};
struct AudioBehaviour_t2DC0BEF7B020C952F3D2DA5AAAC88501C7EEB941  : public Behaviour_t01970CFBBA658497AE30F311C447DB0440BAB7FA
{
};
struct GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0 
{
	ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085 ___Processor;
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 ___Configuration;
};
struct GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshaled_pinvoke
{
	ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085 ___Processor;
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_pinvoke ___Configuration;
};
struct GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshaled_com
{
	ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085 ___Processor;
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_com ___Configuration;
};
struct AudioListener_t1D629CE9BC079C8ECDE8F822616E8A8E319EAE35  : public AudioBehaviour_t2DC0BEF7B020C952F3D2DA5AAAC88501C7EEB941
{
};
struct AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_StaticFields
{
	AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177* ___OnAudioConfigurationChanged;
	Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07* ___OnAudioSystemShuttingDown;
	Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07* ___OnAudioSystemStartedUp;
};
struct String_t_StaticFields
{
	String_t* ___Empty;
};
struct Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_StaticFields
{
	bool ___U3CmuteStateU3Ek__BackingField;
	bool ____stopAudioOutputOnMute;
	Action_1_t10DCB0C07D0D3C565CEACADC80D1152B35A45F6C* ___OnMuteStateChanged;
};
struct Boolean_t09A6377A54BE2F9E6985A8149F19234FD7DDFE22_StaticFields
{
	String_t* ___TrueString;
	String_t* ___FalseString;
};
struct DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E_StaticFields
{
	DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E ___Zero;
	DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E ___MinValue;
	DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E ___MaxValue;
	int32_t ___TicksPerSecondBits;
	int32_t ___NonPow2TpsBits;
};
struct IntPtr_t_StaticFields
{
	intptr_t ___Zero;
};
struct Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C_StaticFields
{
	int32_t ___OffsetOfInstanceIDInCPlusPlusObject;
};
struct PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4_StaticFields
{
	PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 ___m_Null;
};
#ifdef __clang__
#pragma clang diagnostic pop
#endif
struct DelegateU5BU5D_tC5AB7E8F745616680F337909D3A8E6C722CDF771  : public RuntimeArray
{
	ALIGN_FIELD (8) Delegate_t* m_Items[1];

	inline Delegate_t* GetAt(il2cpp_array_size_t index) const
	{
		IL2CPP_ARRAY_BOUNDS_CHECK(index, (uint32_t)(this)->max_length);
		return m_Items[index];
	}
	inline Delegate_t** GetAddressAt(il2cpp_array_size_t index)
	{
		IL2CPP_ARRAY_BOUNDS_CHECK(index, (uint32_t)(this)->max_length);
		return m_Items + index;
	}
	inline void SetAt(il2cpp_array_size_t index, Delegate_t* value)
	{
		IL2CPP_ARRAY_BOUNDS_CHECK(index, (uint32_t)(this)->max_length);
		m_Items[index] = value;
		Il2CppCodeGenWriteBarrier((void**)m_Items + index, (void*)value);
	}
	inline Delegate_t* GetAtUnchecked(il2cpp_array_size_t index) const
	{
		return m_Items[index];
	}
	inline Delegate_t** GetAddressAtUnchecked(il2cpp_array_size_t index)
	{
		return m_Items + index;
	}
	inline void SetAtUnchecked(il2cpp_array_size_t index, Delegate_t* value)
	{
		m_Items[index] = value;
		Il2CppCodeGenWriteBarrier((void**)m_Items + index, (void*)value);
	}
};
struct SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C  : public RuntimeArray
{
	ALIGN_FIELD (8) float m_Items[1];

	inline float GetAt(il2cpp_array_size_t index) const
	{
		IL2CPP_ARRAY_BOUNDS_CHECK(index, (uint32_t)(this)->max_length);
		return m_Items[index];
	}
	inline float* GetAddressAt(il2cpp_array_size_t index)
	{
		IL2CPP_ARRAY_BOUNDS_CHECK(index, (uint32_t)(this)->max_length);
		return m_Items + index;
	}
	inline void SetAt(il2cpp_array_size_t index, float value)
	{
		IL2CPP_ARRAY_BOUNDS_CHECK(index, (uint32_t)(this)->max_length);
		m_Items[index] = value;
	}
	inline float GetAtUnchecked(il2cpp_array_size_t index) const
	{
		return m_Items[index];
	}
	inline float* GetAddressAtUnchecked(il2cpp_array_size_t index)
	{
		return m_Items + index;
	}
	inline void SetAtUnchecked(il2cpp_array_size_t index, float value)
	{
		m_Items[index] = value;
	}
};
struct ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A  : public RuntimeArray
{
	ALIGN_FIELD (8) Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525 m_Items[1];

	inline Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525 GetAt(il2cpp_array_size_t index) const
	{
		IL2CPP_ARRAY_BOUNDS_CHECK(index, (uint32_t)(this)->max_length);
		return m_Items[index];
	}
	inline Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525* GetAddressAt(il2cpp_array_size_t index)
	{
		IL2CPP_ARRAY_BOUNDS_CHECK(index, (uint32_t)(this)->max_length);
		return m_Items + index;
	}
	inline void SetAt(il2cpp_array_size_t index, Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525 value)
	{
		IL2CPP_ARRAY_BOUNDS_CHECK(index, (uint32_t)(this)->max_length);
		m_Items[index] = value;
	}
	inline Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525 GetAtUnchecked(il2cpp_array_size_t index) const
	{
		return m_Items[index];
	}
	inline Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525* GetAddressAtUnchecked(il2cpp_array_size_t index)
	{
		return m_Items + index;
	}
	inline void SetAtUnchecked(il2cpp_array_size_t index, Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525 value)
	{
		m_Items[index] = value;
	}
};
struct WebCamDeviceU5BU5D_tA5B1352BDE6FE233B66C3ABF96E00EB3215629F5  : public RuntimeArray
{
	ALIGN_FIELD (8) WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C m_Items[1];

	inline WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C GetAt(il2cpp_array_size_t index) const
	{
		IL2CPP_ARRAY_BOUNDS_CHECK(index, (uint32_t)(this)->max_length);
		return m_Items[index];
	}
	inline WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C* GetAddressAt(il2cpp_array_size_t index)
	{
		IL2CPP_ARRAY_BOUNDS_CHECK(index, (uint32_t)(this)->max_length);
		return m_Items + index;
	}
	inline void SetAt(il2cpp_array_size_t index, WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C value)
	{
		IL2CPP_ARRAY_BOUNDS_CHECK(index, (uint32_t)(this)->max_length);
		m_Items[index] = value;
		Il2CppCodeGenWriteBarrier((void**)&((m_Items + index)->___m_Name), (void*)NULL);
		#if IL2CPP_ENABLE_STRICT_WRITE_BARRIERS
		Il2CppCodeGenWriteBarrier((void**)&((m_Items + index)->___m_DepthCameraName), (void*)NULL);
		#endif
		#if IL2CPP_ENABLE_STRICT_WRITE_BARRIERS
		Il2CppCodeGenWriteBarrier((void**)&((m_Items + index)->___m_Resolutions), (void*)NULL);
		#endif
	}
	inline WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C GetAtUnchecked(il2cpp_array_size_t index) const
	{
		return m_Items[index];
	}
	inline WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C* GetAddressAtUnchecked(il2cpp_array_size_t index)
	{
		return m_Items + index;
	}
	inline void SetAtUnchecked(il2cpp_array_size_t index, WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C value)
	{
		m_Items[index] = value;
		Il2CppCodeGenWriteBarrier((void**)&((m_Items + index)->___m_Name), (void*)NULL);
		#if IL2CPP_ENABLE_STRICT_WRITE_BARRIERS
		Il2CppCodeGenWriteBarrier((void**)&((m_Items + index)->___m_DepthCameraName), (void*)NULL);
		#endif
		#if IL2CPP_ENABLE_STRICT_WRITE_BARRIERS
		Il2CppCodeGenWriteBarrier((void**)&((m_Items + index)->___m_Resolutions), (void*)NULL);
		#endif
	}
};

IL2CPP_EXTERN_C void Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_pinvoke(const Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060& unmarshaled, Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_pinvoke& marshaled);
IL2CPP_EXTERN_C void Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_pinvoke_back(const Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_pinvoke& marshaled, Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060& unmarshaled);
IL2CPP_EXTERN_C void Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_pinvoke_cleanup(Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_pinvoke& marshaled);
IL2CPP_EXTERN_C void Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_com(const Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060& unmarshaled, Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_com& marshaled);
IL2CPP_EXTERN_C void Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_com_back(const Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_com& marshaled, Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060& unmarshaled);
IL2CPP_EXTERN_C void Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_com_cleanup(Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_com& marshaled);

IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void Action_1_Invoke_m5A038831CEB84A7E374FE59D43444412629F833F_gshared_inline (Action_1_t923A20D1D4F6B55B2ED5AE21B90F1A0CE0450D99* __this, Il2CppFullySharedGenericAny ___0_obj, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR intptr_t MarshalledUnityObject_MarshalNotNull_TisIl2CppSharedGenericObject_mCE897EC9A79983B4B1E6E2C8342452256309044A_gshared_inline (Il2CppSharedGenericObject* ___0_obj, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void Nullable_1__ctor_m4257D7FF23A495D1B204F20330FBDED58248E4CC_gshared (Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339* __this, Il2CppFullySharedGenericStruct ___0_value, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool Nullable_1_get_HasValue_m14F273FB376DF00D727434CDCD28AB4EDCC14C3C_gshared_inline (Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void Nullable_1_get_Value_mA083C4D9192050DC38513BDD9D364C5C68A3A675_gshared (Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339* __this, Il2CppFullySharedGenericStruct* il2cppRetVal, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR intptr_t MarshalledUnityObject_Marshal_TisIl2CppSharedGenericObject_m35CB06885EF5600EDBB840B54EDAF3A806896DBB_gshared_inline (Il2CppSharedGenericObject* ___0_obj, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void Nullable_1_GetValueOrDefault_mC057FBD944AF068B90EBDD0B496231A01B2A4228_gshared_inline (Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339* __this, Il2CppFullySharedGenericStruct* il2cppRetVal, const RuntimeMethod* method) ;

IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void Attribute__ctor_m79ED1BF1EE36D1E417BA89A0D9F91F8AAD8D19E2 (Attribute_tFDA8EFEFB0711976D22474794576DAF28F7440AA* __this, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void AudioConfigurationChangeHandler_Invoke_m4DC27DD11512481B60071B20284E6886DAE54DE2_inline (AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177* __this, bool ___0_deviceWasChanged, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void Action_Invoke_m7126A54DACA72B845424072887B5F3A51FC3808E_inline (Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07* __this, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool Mobile_get_muteState_m64C1E8C61537317A7F153E1A72F7D39D85DA684D_inline (const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void Mobile_set_muteState_m7C9A464BCA3762330E18CCAD79AF6C47B863CA02_inline (bool ___0_value, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool Mobile_get_stopAudioOutputOnMute_m43EC82258D38C418353DFE19F32B51B64B18DCCA_inline (const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void Mobile_StopAudioOutput_m10B8CEF668EE4967D0AD1D6741B6A37540C28A46 (const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void Mobile_StartAudioOutput_m731D1EEEE7A0D56BAADD571BA0FCAC13FB071223 (const RuntimeMethod* method) ;
inline void Action_1_Invoke_m69C8773D6967F3B224777183E24EA621CE056F8F_inline (Action_1_t10DCB0C07D0D3C565CEACADC80D1152B35A45F6C* __this, bool ___0_obj, const RuntimeMethod* method)
{
	((  void (*) (Action_1_t923A20D1D4F6B55B2ED5AE21B90F1A0CE0450D99*, Il2CppFullySharedGenericAny, const RuntimeMethod*))Action_1_Invoke_m5A038831CEB84A7E374FE59D43444412629F833F_gshared_inline)((Action_1_t923A20D1D4F6B55B2ED5AE21B90F1A0CE0450D99*)__this, (Il2CppFullySharedGenericAny)&___0_obj, method);
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioSettings_StartAudioOutput_mB04D851DD0E6115DEEFB55779F880146263C67BE (const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioSettings_StopAudioOutput_m3FE7A8EADAB2FB570BB05F7C353E25E15885D1CB (const RuntimeMethod* method) ;
inline intptr_t MarshalledUnityObject_MarshalNotNull_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_mC3A4EC248FAFFBF10CD74B1E57A203FE7D9E01F5_inline (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* ___0_obj, const RuntimeMethod* method)
{
	return ((  intptr_t (*) (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20*, const RuntimeMethod*))MarshalledUnityObject_MarshalNotNull_TisIl2CppSharedGenericObject_mCE897EC9A79983B4B1E6E2C8342452256309044A_gshared_inline)(___0_obj, method);
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void ThrowHelper_ThrowNullReferenceException_mA9C7629D32240EE0218631933DAC647668CA63CF (RuntimeObject* ___0_obj, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioClip_IsLegacyFormat_Injected_m7072F5FDC54820CA887B98DF51BB23B5AB29D751 (intptr_t ___0__unity_self, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t AudioClip_get_samples_Injected_m18E5C4BD533706C80A8780D7439E151E305479F5 (intptr_t ___0__unity_self, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t AudioClip_get_frequency_Injected_m88A5AA18CEDCC1F528AF69A95C23ED5ADD39136B (intptr_t ___0__unity_self, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void PCMReaderCallback_Invoke_m76784C690C36B513E2AA5B0E4FD9831B2C7E5152_inline (PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E* __this, SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C* ___0_data, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void PCMSetPositionCallback_Invoke_m434D4F02FA25F91DF6199EC5A799C551C7F93702_inline (PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072* __this, int32_t ___0_position, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioClip_IsLegacyFormat_m3DB8BD55B7C96596B031D7E2AE5B430C00CE4D58 (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR String_t* Object_get_name_mAC2F6B897CF1303BA4249B4CB55271AFACBB6392 (Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR String_t* String_Concat_m8855A6DE10F84DA7F4EC113CADDB59873A25573B (String_t* ___0_str0, String_t* ___1_str1, String_t* ___2_str2, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void NotSupportedException__ctor_mE174750CF0247BBB47544FFD71D66BB89630945B (NotSupportedException_t1429765983D409BD2986508963C98D214E4EBF4A* __this, String_t* ___0_message, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void AudioClip_CheckIsNotPersistent_m9792AEB282CC66210DDB73702C33EF5FC001313C (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t AudioClip_get_samples_mDEA01CA75E7DEA0F8D480E4AF97FB96085BCF38E (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t AudioClip_get_frequency_m6647E10F4B2B1335187B0066E82468CCCF19647B (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int64_t Configuration_FramesAndSampleRateToDiscreteTimeTicks_mD8442DC6E7541DA57E38136E474B09FA2A8CC066 (int64_t ___0_lengthFrames, uint32_t ___1_sampleRate, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E DiscreteTime_FromTicks_m0AF37F302A6729B9C86ACBBBF3CA26471DF131BC_inline (int64_t ___0_v, const RuntimeMethod* method) ;
inline void Nullable_1__ctor_mA3535F58A54E060F67F4FFB3A5974A10D6444604 (Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363* __this, DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E ___0_value, const RuntimeMethod* method)
{
	((  void (*) (Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339*, Il2CppFullySharedGenericStruct, const RuntimeMethod*))Nullable_1__ctor_m4257D7FF23A495D1B204F20330FBDED58248E4CC_gshared)((Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339*)__this, (Il2CppFullySharedGenericStruct)&___0_value, method);
}
inline bool Nullable_1_get_HasValue_m0A28F36C93C270B2B16241740BA7B9CFE0166F7A_inline (Nullable_1_t8743998EB2E7DB936C93772849EF306FBD5C5EE5* __this, const RuntimeMethod* method)
{
	return ((  bool (*) (Nullable_1_t8743998EB2E7DB936C93772849EF306FBD5C5EE5*, const RuntimeMethod*))Nullable_1_get_HasValue_m14F273FB376DF00D727434CDCD28AB4EDCC14C3C_gshared_inline)(__this, method);
}
inline AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D Nullable_1_get_Value_m32D74DBCABD51FD09C2289F4AB5813C51FD97782 (Nullable_1_t8743998EB2E7DB936C93772849EF306FBD5C5EE5* __this, const RuntimeMethod* method)
{
	AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D il2cppRetVal;
	((  void (*) (Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339*, Il2CppFullySharedGenericStruct*, const RuntimeMethod*))Nullable_1_get_Value_mA083C4D9192050DC38513BDD9D364C5C68A3A675_gshared)((Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339*)__this, (Il2CppFullySharedGenericStruct*)&il2cppRetVal, method);
	return il2cppRetVal;
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D AudioFormat_get_audioConfiguration_m769CBA67D62C1D12FBE6C55DC2429D62BA135D43_inline (AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D* __this, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* ControlContext_get_Header_m48ED40585DBA374B2750157BEFD1A0DC92B654E2_inline (ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void* SampleProviderBindings_CreateGeneratorHeader_m431C7ACC029F1B61B5C7C81F894FED9AA6C5F640 (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* ___0_audioClip, void* ___1_resourceHeader, AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D* ___2_nestedConfiguration, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void GeneratorInstance__ctor_m918C508DE9944B098D0305A557F6BDC7227C3518 (GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* __this, GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0* ___0_header, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_inline (SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* __this, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2* ___0_provider, uint32_t ___1_sampleFrameCount, const RuntimeMethod* method) ;
inline intptr_t MarshalledUnityObject_Marshal_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_m4CF5833467B7EAC854506E5E808202FABD1F15CC_inline (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* ___0_obj, const RuntimeMethod* method)
{
	return ((  intptr_t (*) (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20*, const RuntimeMethod*))MarshalledUnityObject_Marshal_TisIl2CppSharedGenericObject_m35CB06885EF5600EDBB840B54EDAF3A806896DBB_gshared_inline)(___0_obj, method);
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void* SampleProviderBindings_CreateGeneratorHeader_Injected_m5BC947EEDEA293BBFD0508BE58B6254B6A49CC4F (intptr_t ___0_audioClip, void* ___1_resourceHeader, AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D* ___2_nestedConfiguration, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 AudioClipPlayable_GetHandle_mEA1D664328FF9B08E4F7D5EBCD4B51A754D97C44_inline (AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool PlayableHandle_op_Equality_m0E6C48A28F75A870AC22ADE3BD42F7F70A43C99C (PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 ___0_x, PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 ___1_y, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioClipPlayable_Equals_m9C1C75ACBB74FE06AD02BE4643F6EB39413EFF83 (AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0* __this, AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0 ___0_other, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 AudioMixerPlayable_GetHandle_m6C182D9794E901D123223BB57738A302BEAB41FD_inline (AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioMixerPlayable_Equals_mDFB945EB48199A338BAD00D40FB8EEC34CF64D57 (AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C* __this, AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C ___0_other, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void Handle_CheckValidOrThrow_mA6C3BAA711CDA462A6A2653A1A2D04CE2AECD3C3 (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void ControlContext__ctor_mFFC3A14E72F61DACB51F4F771FAE8416702023B6 (ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* __this, void* ___0_headerThatShouldBeOfResourceType, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool ScriptableProcessorBindings_CheckProcessorExists_mCA17BD1A2B9E776034C7B312CA810B3B739AA04E (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___0_handle, ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* ___1_control, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool ControlContext_Exists_mEEB0CCB244CABE9EAD81EBC5E54CB6B50E18FA0F (ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* __this, ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 ___0_processorInstance, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 ControlContext_GetConfiguration_m5EF5175CD07C7E1661F6AC36ECEA52A293DB0249 (ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* __this, GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 ___0_generatorInstance, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool IntPtr_op_Inequality_m90EFC9C4CAD9A33E309F2DDF98EE4E1DD253637B_inline (intptr_t ___0_value1, intptr_t ___1_value2, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR GCHandle_tC44F6F72EE68BD4CFABA24309DA7A179D41127DC GCHandle_FromIntPtr_mA7848A4285D007CADC52B6272DB243C8FDFD5FAC (intptr_t ___0_value, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool GCHandle_get_IsAllocated_m241908103D8D867E11CCAB73C918729825E86843_inline (GCHandle_tC44F6F72EE68BD4CFABA24309DA7A179D41127DC* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void GCHandle_Free_m1320A260E487EB1EA6D95F9E54BFFCB5A4EF83A3 (GCHandle_tC44F6F72EE68BD4CFABA24309DA7A179D41127DC* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool ProcessorInstance_Equals_m4873E7D141484FCADC7F0F9C64542D57E0D02398 (ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* __this, ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 ___0_other, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool GeneratorInstance_Equals_m1FEFD7862F181D69396710522A061AA1A5189FE1 (GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* __this, GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 ___0_other, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool GeneratorInstance_Equals_m7412F772B53B5052FF5070FB2BB2099A93270206 (GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* __this, RuntimeObject* ___0_obj, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t ProcessorInstance_GetHashCode_m607D39F5BA947B94238348CF61431A9D8049F9B0 (ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t GeneratorInstance_GetHashCode_mBF9BB29BE3D212AAAEF53A02346FED4B0435C7D2 (GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void ProcessorInstance__ctor_m3E0B9039361DE404D8DF604C8D6E324B2F6CC36B (ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* __this, Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___0_handle, ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085* ___1_header, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool Configuration_get_isRealtime_m99E988C200947A8277C144A84CB1755B5A0C2D78_inline (Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 Configuration_get_length_mB699EC1CF6B8A0955A60B55ABB22AD00A3F6BC3B (Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool Handle_Equals_m5D8356E5FCA91FFFEACC910C738C37690EBA2E64 (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* __this, Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___0_other, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool ProcessorInstance_Equals_mFE0F0DA5B311AD6D34EABD73F61C4AE3014084ED (ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* __this, RuntimeObject* ___0_obj, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t Handle_GetHashCode_m8DD5E2EE5197C1FF37CD2CF3B4FD892A9E299DFE (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* __this, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 GeneratorInstance_op_Implicit_mB7A6E46130D3BAB42E00F4DD08155EF286A16167_inline (GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* ___0_generatorInstance, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR String_t* String_Format_mA0534D6E2AE4D67A6BD8D45B3321323930EB930C (String_t* ___0_format, RuntimeObject* ___1_arg0, RuntimeObject* ___2_arg1, RuntimeObject* ___3_arg2, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void Debug_LogError_mB00B2B4468EF3CAF041B038D840820FB84C924B2 (RuntimeObject* ___0_message, const RuntimeMethod* method) ;
inline bool Nullable_1_get_HasValue_m2C09C399366A16930BBC996441FE7CED2907D3D0_inline (Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363* __this, const RuntimeMethod* method)
{
	return ((  bool (*) (Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363*, const RuntimeMethod*))Nullable_1_get_HasValue_m14F273FB376DF00D727434CDCD28AB4EDCC14C3C_gshared_inline)(__this, method);
}
inline DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E Nullable_1_GetValueOrDefault_m5879DF28E8CBC03BD7B2F3A7B383BB0068DE64DC_inline (Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363* __this, const RuntimeMethod* method)
{
	DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E il2cppRetVal;
	((  void (*) (Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339*, Il2CppFullySharedGenericStruct*, const RuntimeMethod*))Nullable_1_GetValueOrDefault_mC057FBD944AF068B90EBDD0B496231A01B2A4228_gshared_inline)((Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339*)__this, (Il2CppFullySharedGenericStruct*)&il2cppRetVal, method);
	return il2cppRetVal;
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool DiscreteTime_op_Inequality_m4C12F6A54E5C6E8BAC45A3903E6C2A3127C6063C_inline (DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E ___0_lhs, DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E ___1_rhs, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR String_t* String_Format_mFB7DA489BD99F4670881FF50EC017BFB0A5C0987 (String_t* ___0_format, RuntimeObject* ___1_arg0, RuntimeObject* ___2_arg1, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool ScriptableProcessorBindings_CheckProcessorExistsInternal_mF6C33BA9D06B46EAAA47D05E74BA20CC604141A6 (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___0_handle, void* ___1_control, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool ScriptableProcessorBindings_CheckProcessorExistsInternal_Injected_mD29018C86FF29463FEC0346E4D8308F7F6EA1831 (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* ___0_handle, void* ___1_control, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void* IntPtr_op_Explicit_m2728CBA081E79B97DDCF1D4FAD77B309CA1E94BF (intptr_t ___0_value, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR Node_tE9DD997AC2A1CDC0DF9579D3B88467E7F42142C8* Handle_get_AtomicNode_m3D7AF7852BDF5999877F8F973FDF8724974B0A50 (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* __this, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool IntPtr_op_Equality_m7D9CDCDE9DC2A0C2C614633F4921E90187FAB271_inline (intptr_t ___0_value1, intptr_t ___1_value2, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool Handle_Equals_mDE217E745B1016A74BCE82848675ED913B391B8F (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* __this, RuntimeObject* ___0_obj, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t IntPtr_op_Explicit_mC33775570B5AC86421DABA8F8B9885DBFF49B02F (intptr_t ___0_value, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool Handle_get_ValidAndNotDisposed_m1097F1E099632EDF74478AD5B74978BD3FAEF145 (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* __this, const RuntimeMethod* method) ;
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void InvalidOperationException__ctor_mE4CB6F4712AB6D99A2358FBAE2E052B3EE976162 (InvalidOperationException_t5DDE4D49B7405FAAB1E4576F4715A42A3FAD4BAB* __this, String_t* ___0_message, const RuntimeMethod* method) ;
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void DiscreteTime__ctor_m5DF0E73E12BD613EE452B88012E01EF83E70383E_inline (DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E* __this, int64_t ___0_v, int32_t ___1__, const RuntimeMethod* method) ;
inline intptr_t MarshalledUnityObject_MarshalNotNull_TisIl2CppSharedGenericObject_mCE897EC9A79983B4B1E6E2C8342452256309044A_inline (Il2CppSharedGenericObject* ___0_obj, const RuntimeMethod* method)
{
	return ((  intptr_t (*) (Il2CppSharedGenericObject*, const RuntimeMethod*))MarshalledUnityObject_MarshalNotNull_TisIl2CppSharedGenericObject_mCE897EC9A79983B4B1E6E2C8342452256309044A_gshared_inline)(___0_obj, method);
}
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void EmbeddedAttribute__ctor_m435F561C10EB1CFADACDF6202954D45787911FDE (EmbeddedAttribute_tDFF02CAA8432C01BCA04CBAB5F8600F62813A849* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&EmbeddedAttribute__ctor_m435F561C10EB1CFADACDF6202954D45787911FDE_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, EmbeddedAttribute__ctor_m435F561C10EB1CFADACDF6202954D45787911FDE_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_PAUSE_POINT;
	{
		Attribute__ctor_m79ED1BF1EE36D1E417BA89A0D9F91F8AAD8D19E2(__this, NULL);
		return;
	}
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void RefSafetyRulesAttribute__ctor_m35BCB21D10EE61C71ED4F6CA05DE681A759393A6 (RefSafetyRulesAttribute_tBA6EA196F2B7FCDEDF930A6583457BBFB7B4DDF2* __this, int32_t ___0_p, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&RefSafetyRulesAttribute__ctor_m35BCB21D10EE61C71ED4F6CA05DE681A759393A6_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, RefSafetyRulesAttribute__ctor_m35BCB21D10EE61C71ED4F6CA05DE681A759393A6_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_PAUSE_POINT;
	{
		Attribute__ctor_m79ED1BF1EE36D1E417BA89A0D9F91F8AAD8D19E2(__this, NULL);
		int32_t L_0 = ___0_p;
		__this->___Version = L_0;
		return;
	}
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void AudioSettings_InvokeOnAudioConfigurationChanged_m8273D3AEB24F4C3E374238B6F699BE6696808E85 (bool ___0_deviceWasChanged, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioSettings_InvokeOnAudioConfigurationChanged_m8273D3AEB24F4C3E374238B6F699BE6696808E85_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_deviceWasChanged));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioSettings_InvokeOnAudioConfigurationChanged_m8273D3AEB24F4C3E374238B6F699BE6696808E85_RuntimeMethod_var, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 0));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 1));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 2));
		AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177* L_0 = ((AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_StaticFields*)il2cpp_codegen_static_fields_for(AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_il2cpp_TypeInfo_var))->___OnAudioConfigurationChanged;
		if (!L_0)
		{
			goto IL_0012;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 3));
		AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177* L_1 = ((AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_StaticFields*)il2cpp_codegen_static_fields_for(AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_il2cpp_TypeInfo_var))->___OnAudioConfigurationChanged;
		bool L_2 = ___0_deviceWasChanged;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 4));
		NullCheck(L_1);
		AudioConfigurationChangeHandler_Invoke_m4DC27DD11512481B60071B20284E6886DAE54DE2_inline(L_1, L_2, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 4));
	}

IL_0012:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 5));
		return;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void AudioSettings_InvokeOnAudioSystemShuttingDown_m1B9895D60B3267EBDEC69B9169730DBAD8325E90 (const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioSettings_InvokeOnAudioSystemShuttingDown_m1B9895D60B3267EBDEC69B9169730DBAD8325E90_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioSettings_InvokeOnAudioSystemShuttingDown_m1B9895D60B3267EBDEC69B9169730DBAD8325E90_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 6));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 7));
	Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07* G_B2_0 = NULL;
	Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07* G_B1_0 = NULL;
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 8));
		Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07* L_0 = ((AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_StaticFields*)il2cpp_codegen_static_fields_for(AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_il2cpp_TypeInfo_var))->___OnAudioSystemShuttingDown;
		Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07* L_1 = L_0;
		if (L_1)
		{
			G_B2_0 = L_1;
			goto IL_000a;
		}
		G_B1_0 = L_1;
	}
	{
		return;
	}

IL_000a:
	{
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 9));
		NullCheck(G_B2_0);
		Action_Invoke_m7126A54DACA72B845424072887B5F3A51FC3808E_inline(G_B2_0, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 9));
		return;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void AudioSettings_InvokeOnAudioSystemStartedUp_m7FE042936237E5BDCB20299D8C4CF583B661468C (const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioSettings_InvokeOnAudioSystemStartedUp_m7FE042936237E5BDCB20299D8C4CF583B661468C_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioSettings_InvokeOnAudioSystemStartedUp_m7FE042936237E5BDCB20299D8C4CF583B661468C_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 10));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 11));
	Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07* G_B2_0 = NULL;
	Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07* G_B1_0 = NULL;
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 12));
		Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07* L_0 = ((AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_StaticFields*)il2cpp_codegen_static_fields_for(AudioSettings_t66C4BCA1E463B061E2EC9063FB882ACED20D47BD_il2cpp_TypeInfo_var))->___OnAudioSystemStartedUp;
		Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07* L_1 = L_0;
		if (L_1)
		{
			G_B2_0 = L_1;
			goto IL_000a;
		}
		G_B1_0 = L_1;
	}
	{
		return;
	}

IL_000a:
	{
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 13));
		NullCheck(G_B2_0);
		Action_Invoke_m7126A54DACA72B845424072887B5F3A51FC3808E_inline(G_B2_0, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 13));
		return;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioSettings_StartAudioOutput_mB04D851DD0E6115DEEFB55779F880146263C67BE (const RuntimeMethod* method) 
{
	typedef bool (*AudioSettings_StartAudioOutput_mB04D851DD0E6115DEEFB55779F880146263C67BE_ftn) ();
	static AudioSettings_StartAudioOutput_mB04D851DD0E6115DEEFB55779F880146263C67BE_ftn _il2cpp_icall_func;
	if (!_il2cpp_icall_func)
	_il2cpp_icall_func = (AudioSettings_StartAudioOutput_mB04D851DD0E6115DEEFB55779F880146263C67BE_ftn)il2cpp_codegen_resolve_icall ("UnityEngine.AudioSettings::StartAudioOutput()");
	bool icallRetVal = _il2cpp_icall_func();
	return icallRetVal;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioSettings_StopAudioOutput_m3FE7A8EADAB2FB570BB05F7C353E25E15885D1CB (const RuntimeMethod* method) 
{
	typedef bool (*AudioSettings_StopAudioOutput_m3FE7A8EADAB2FB570BB05F7C353E25E15885D1CB_ftn) ();
	static AudioSettings_StopAudioOutput_m3FE7A8EADAB2FB570BB05F7C353E25E15885D1CB_ftn _il2cpp_icall_func;
	if (!_il2cpp_icall_func)
	_il2cpp_icall_func = (AudioSettings_StopAudioOutput_m3FE7A8EADAB2FB570BB05F7C353E25E15885D1CB_ftn)il2cpp_codegen_resolve_icall ("UnityEngine.AudioSettings::StopAudioOutput()");
	bool icallRetVal = _il2cpp_icall_func();
	return icallRetVal;
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
void AudioConfigurationChangeHandler_Invoke_m4DC27DD11512481B60071B20284E6886DAE54DE2_Multicast(AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177* __this, bool ___0_deviceWasChanged, const RuntimeMethod* method)
{
	il2cpp_array_size_t length = __this->___delegates->max_length;
	Delegate_t** delegatesToInvoke = reinterpret_cast<Delegate_t**>(__this->___delegates->GetAddressAtUnchecked(0));
	for (il2cpp_array_size_t i = 0; i < length; i++)
	{
		AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177* currentDelegate = reinterpret_cast<AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177*>(delegatesToInvoke[i]);
		typedef void (*FunctionPointerType) (RuntimeObject*, bool, const RuntimeMethod*);
		((FunctionPointerType)currentDelegate->___invoke_impl)((Il2CppObject*)currentDelegate->___method_code, ___0_deviceWasChanged, reinterpret_cast<RuntimeMethod*>(currentDelegate->___method));
	}
}
void AudioConfigurationChangeHandler_Invoke_m4DC27DD11512481B60071B20284E6886DAE54DE2_OpenInst(AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177* __this, bool ___0_deviceWasChanged, const RuntimeMethod* method)
{
	typedef void (*FunctionPointerType) (bool, const RuntimeMethod*);
	((FunctionPointerType)__this->___method_ptr)(___0_deviceWasChanged, method);
}
void AudioConfigurationChangeHandler_Invoke_m4DC27DD11512481B60071B20284E6886DAE54DE2_OpenStatic(AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177* __this, bool ___0_deviceWasChanged, const RuntimeMethod* method)
{
	typedef void (*FunctionPointerType) (bool, const RuntimeMethod*);
	((FunctionPointerType)__this->___method_ptr)(___0_deviceWasChanged, method);
}
IL2CPP_EXTERN_C  void DelegatePInvokeWrapper_AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177 (AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177* __this, bool ___0_deviceWasChanged, const RuntimeMethod* method)
{
	typedef void (DEFAULT_CALL *PInvokeFunc)(int32_t);
	PInvokeFunc il2cppPInvokeFunc = reinterpret_cast<PInvokeFunc>(il2cpp_codegen_get_reverse_pinvoke_function_ptr(__this));
	il2cppPInvokeFunc(static_cast<int32_t>(___0_deviceWasChanged));

}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void AudioConfigurationChangeHandler__ctor_mA9827AB9472EC8EE0A0F0FC24EBC06B4740DD944 (AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177* __this, RuntimeObject* ___0_object, intptr_t ___1_method, const RuntimeMethod* method) 
{
	__this->___method_ptr = (intptr_t)il2cpp_codegen_get_method_pointer((RuntimeMethod*)___1_method);
	__this->___method = ___1_method;
	__this->___m_target = ___0_object;
	Il2CppCodeGenWriteBarrier((void**)(&__this->___m_target), (void*)___0_object);
	int parameterCount = il2cpp_codegen_method_parameter_count((RuntimeMethod*)___1_method);
	__this->___method_code = (intptr_t)__this;
	if (MethodIsStatic((RuntimeMethod*)___1_method))
	{
		bool isOpen = parameterCount == 1;
		if (isOpen)
			__this->___invoke_impl = (intptr_t)&AudioConfigurationChangeHandler_Invoke_m4DC27DD11512481B60071B20284E6886DAE54DE2_OpenStatic;
		else
			{
				__this->___invoke_impl = __this->___method_ptr;
				__this->___method_code = (intptr_t)__this->___m_target;
			}
	}
	else
	{
		if (___0_object == NULL)
			il2cpp_codegen_raise_exception(il2cpp_codegen_get_argument_exception(NULL, "Delegate to an instance method cannot have null 'this'."), NULL);
		__this->___invoke_impl = __this->___method_ptr;
		__this->___method_code = (intptr_t)__this->___m_target;
	}
	__this->___extra_arg = (intptr_t)&AudioConfigurationChangeHandler_Invoke_m4DC27DD11512481B60071B20284E6886DAE54DE2_Multicast;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void AudioConfigurationChangeHandler_Invoke_m4DC27DD11512481B60071B20284E6886DAE54DE2 (AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177* __this, bool ___0_deviceWasChanged, const RuntimeMethod* method) 
{
	typedef void (*FunctionPointerType) (RuntimeObject*, bool, const RuntimeMethod*);
	((FunctionPointerType)__this->___invoke_impl)((Il2CppObject*)__this->___method_code, ___0_deviceWasChanged, reinterpret_cast<RuntimeMethod*>(__this->___method));
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool Mobile_get_muteState_m64C1E8C61537317A7F153E1A72F7D39D85DA684D (const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_get_muteState_m64C1E8C61537317A7F153E1A72F7D39D85DA684D_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Mobile_get_muteState_m64C1E8C61537317A7F153E1A72F7D39D85DA684D_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 14));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 15));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 16));
		bool L_0 = ((Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_StaticFields*)il2cpp_codegen_static_fields_for(Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var))->___U3CmuteStateU3Ek__BackingField;
		return L_0;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void Mobile_set_muteState_m7C9A464BCA3762330E18CCAD79AF6C47B863CA02 (bool ___0_value, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_set_muteState_m7C9A464BCA3762330E18CCAD79AF6C47B863CA02_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_value));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Mobile_set_muteState_m7C9A464BCA3762330E18CCAD79AF6C47B863CA02_RuntimeMethod_var, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 17));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 18));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 19));
		bool L_0 = ___0_value;
		((Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_StaticFields*)il2cpp_codegen_static_fields_for(Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var))->___U3CmuteStateU3Ek__BackingField = L_0;
		return;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool Mobile_get_stopAudioOutputOnMute_m43EC82258D38C418353DFE19F32B51B64B18DCCA (const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_get_stopAudioOutputOnMute_m43EC82258D38C418353DFE19F32B51B64B18DCCA_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Mobile_get_stopAudioOutputOnMute_m43EC82258D38C418353DFE19F32B51B64B18DCCA_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 20));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 21));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 22));
		bool L_0 = ((Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_StaticFields*)il2cpp_codegen_static_fields_for(Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var))->____stopAudioOutputOnMute;
		return L_0;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void Mobile_InvokeOnMuteStateChanged_mE5242862F948BA9FBB013A2B45F645B6A21E6198 (bool ___0_mute, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_InvokeOnMuteStateChanged_mE5242862F948BA9FBB013A2B45F645B6A21E6198_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_mute));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Mobile_InvokeOnMuteStateChanged_mE5242862F948BA9FBB013A2B45F645B6A21E6198_RuntimeMethod_var, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 23));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 24));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 25));
		bool L_0 = ___0_mute;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 26));
		bool L_1;
		L_1 = Mobile_get_muteState_m64C1E8C61537317A7F153E1A72F7D39D85DA684D_inline(NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 26));
		if ((((int32_t)L_0) == ((int32_t)L_1)))
		{
			goto IL_003a;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 27));
		bool L_2 = ___0_mute;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 28));
		Mobile_set_muteState_m7C9A464BCA3762330E18CCAD79AF6C47B863CA02_inline(L_2, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 28));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 29));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 30));
		bool L_3;
		L_3 = Mobile_get_stopAudioOutputOnMute_m43EC82258D38C418353DFE19F32B51B64B18DCCA_inline(NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 30));
		if (!L_3)
		{
			goto IL_0028;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 31));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 32));
		bool L_4;
		L_4 = Mobile_get_muteState_m64C1E8C61537317A7F153E1A72F7D39D85DA684D_inline(NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 32));
		if (!L_4)
		{
			goto IL_0023;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 33));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 34));
		Mobile_StopAudioOutput_m10B8CEF668EE4967D0AD1D6741B6A37540C28A46(NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 34));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 35));
		goto IL_0028;
	}

IL_0023:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 36));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 37));
		Mobile_StartAudioOutput_m731D1EEEE7A0D56BAADD571BA0FCAC13FB071223(NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 37));
	}

IL_0028:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 38));
		Action_1_t10DCB0C07D0D3C565CEACADC80D1152B35A45F6C* L_5 = ((Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_StaticFields*)il2cpp_codegen_static_fields_for(Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var))->___OnMuteStateChanged;
		if (!L_5)
		{
			goto IL_003a;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 39));
		Action_1_t10DCB0C07D0D3C565CEACADC80D1152B35A45F6C* L_6 = ((Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_StaticFields*)il2cpp_codegen_static_fields_for(Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var))->___OnMuteStateChanged;
		bool L_7 = ___0_mute;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 40));
		NullCheck(L_6);
		Action_1_Invoke_m69C8773D6967F3B224777183E24EA621CE056F8F_inline(L_6, L_7, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 40));
	}

IL_003a:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 41));
		return;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool Mobile_InvokeIsStopAudioOutputOnMuteEnabled_m854CB455C7BE7ADC06BABCB9AA24F60309AE7ED1 (const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_InvokeIsStopAudioOutputOnMuteEnabled_m854CB455C7BE7ADC06BABCB9AA24F60309AE7ED1_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Mobile_InvokeIsStopAudioOutputOnMuteEnabled_m854CB455C7BE7ADC06BABCB9AA24F60309AE7ED1_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 42));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 43));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 44));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 45));
		bool L_0;
		L_0 = Mobile_get_stopAudioOutputOnMute_m43EC82258D38C418353DFE19F32B51B64B18DCCA_inline(NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 45));
		return L_0;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void Mobile_StartAudioOutput_m731D1EEEE7A0D56BAADD571BA0FCAC13FB071223 (const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_StartAudioOutput_m731D1EEEE7A0D56BAADD571BA0FCAC13FB071223_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Mobile_StartAudioOutput_m731D1EEEE7A0D56BAADD571BA0FCAC13FB071223_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 46));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 47));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 48));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 49));
		bool L_0;
		L_0 = AudioSettings_StartAudioOutput_mB04D851DD0E6115DEEFB55779F880146263C67BE(NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 49));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 50));
		return;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void Mobile_StopAudioOutput_m10B8CEF668EE4967D0AD1D6741B6A37540C28A46 (const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_StopAudioOutput_m10B8CEF668EE4967D0AD1D6741B6A37540C28A46_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Mobile_StopAudioOutput_m10B8CEF668EE4967D0AD1D6741B6A37540C28A46_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 51));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 52));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 53));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 54));
		bool L_0;
		L_0 = AudioSettings_StopAudioOutput_m3FE7A8EADAB2FB570BB05F7C353E25E15885D1CB(NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 54));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 55));
		return;
	}
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioClip_IsLegacyFormat_m3DB8BD55B7C96596B031D7E2AE5B430C00CE4D58 (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_IsLegacyFormat_m3DB8BD55B7C96596B031D7E2AE5B430C00CE4D58_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&MarshalledUnityObject_MarshalNotNull_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_mC3A4EC248FAFFBF10CD74B1E57A203FE7D9E01F5_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClip_IsLegacyFormat_m3DB8BD55B7C96596B031D7E2AE5B430C00CE4D58_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_PAUSE_POINT;
	intptr_t G_B2_0;
	memset((&G_B2_0), 0, sizeof(G_B2_0));
	intptr_t G_B1_0;
	memset((&G_B1_0), 0, sizeof(G_B1_0));
	{
		intptr_t L_0;
		L_0 = MarshalledUnityObject_MarshalNotNull_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_mC3A4EC248FAFFBF10CD74B1E57A203FE7D9E01F5_inline(__this, MarshalledUnityObject_MarshalNotNull_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_mC3A4EC248FAFFBF10CD74B1E57A203FE7D9E01F5_RuntimeMethod_var);
		intptr_t L_1 = L_0;
		if (L_1)
		{
			G_B2_0 = L_1;
			goto IL_000f;
		}
		G_B1_0 = L_1;
	}
	{
		ThrowHelper_ThrowNullReferenceException_mA9C7629D32240EE0218631933DAC647668CA63CF(__this, NULL);
		G_B2_0 = G_B1_0;
	}

IL_000f:
	{
		bool L_2;
		L_2 = AudioClip_IsLegacyFormat_Injected_m7072F5FDC54820CA887B98DF51BB23B5AB29D751(G_B2_0, NULL);
		return L_2;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t AudioClip_get_samples_mDEA01CA75E7DEA0F8D480E4AF97FB96085BCF38E (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_get_samples_mDEA01CA75E7DEA0F8D480E4AF97FB96085BCF38E_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&MarshalledUnityObject_MarshalNotNull_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_mC3A4EC248FAFFBF10CD74B1E57A203FE7D9E01F5_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClip_get_samples_mDEA01CA75E7DEA0F8D480E4AF97FB96085BCF38E_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_PAUSE_POINT;
	intptr_t G_B2_0;
	memset((&G_B2_0), 0, sizeof(G_B2_0));
	intptr_t G_B1_0;
	memset((&G_B1_0), 0, sizeof(G_B1_0));
	{
		intptr_t L_0;
		L_0 = MarshalledUnityObject_MarshalNotNull_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_mC3A4EC248FAFFBF10CD74B1E57A203FE7D9E01F5_inline(__this, MarshalledUnityObject_MarshalNotNull_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_mC3A4EC248FAFFBF10CD74B1E57A203FE7D9E01F5_RuntimeMethod_var);
		intptr_t L_1 = L_0;
		if (L_1)
		{
			G_B2_0 = L_1;
			goto IL_000f;
		}
		G_B1_0 = L_1;
	}
	{
		ThrowHelper_ThrowNullReferenceException_mA9C7629D32240EE0218631933DAC647668CA63CF(__this, NULL);
		G_B2_0 = G_B1_0;
	}

IL_000f:
	{
		int32_t L_2;
		L_2 = AudioClip_get_samples_Injected_m18E5C4BD533706C80A8780D7439E151E305479F5(G_B2_0, NULL);
		return L_2;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t AudioClip_get_frequency_m6647E10F4B2B1335187B0066E82468CCCF19647B (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_get_frequency_m6647E10F4B2B1335187B0066E82468CCCF19647B_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&MarshalledUnityObject_MarshalNotNull_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_mC3A4EC248FAFFBF10CD74B1E57A203FE7D9E01F5_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClip_get_frequency_m6647E10F4B2B1335187B0066E82468CCCF19647B_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_PAUSE_POINT;
	intptr_t G_B2_0;
	memset((&G_B2_0), 0, sizeof(G_B2_0));
	intptr_t G_B1_0;
	memset((&G_B1_0), 0, sizeof(G_B1_0));
	{
		intptr_t L_0;
		L_0 = MarshalledUnityObject_MarshalNotNull_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_mC3A4EC248FAFFBF10CD74B1E57A203FE7D9E01F5_inline(__this, MarshalledUnityObject_MarshalNotNull_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_mC3A4EC248FAFFBF10CD74B1E57A203FE7D9E01F5_RuntimeMethod_var);
		intptr_t L_1 = L_0;
		if (L_1)
		{
			G_B2_0 = L_1;
			goto IL_000f;
		}
		G_B1_0 = L_1;
	}
	{
		ThrowHelper_ThrowNullReferenceException_mA9C7629D32240EE0218631933DAC647668CA63CF(__this, NULL);
		G_B2_0 = G_B1_0;
	}

IL_000f:
	{
		int32_t L_2;
		L_2 = AudioClip_get_frequency_Injected_m88A5AA18CEDCC1F528AF69A95C23ED5ADD39136B(G_B2_0, NULL);
		return L_2;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void AudioClip_InvokePCMReaderCallback_Internal_m766E5705AB5AE16F5F142867CC3758ABE4BF462C (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C* ___0_data, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_InvokePCMReaderCallback_Internal_m766E5705AB5AE16F5F142867CC3758ABE4BF462C_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_data));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClip_InvokePCMReaderCallback_Internal_m766E5705AB5AE16F5F142867CC3758ABE4BF462C_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 56));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 57));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 58));
		PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E* L_0 = __this->___m_PCMReaderCallback;
		if (!L_0)
		{
			goto IL_0014;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 59));
		PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E* L_1 = __this->___m_PCMReaderCallback;
		SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C* L_2 = ___0_data;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 60));
		NullCheck(L_1);
		PCMReaderCallback_Invoke_m76784C690C36B513E2AA5B0E4FD9831B2C7E5152_inline(L_1, L_2, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 60));
	}

IL_0014:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 61));
		return;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void AudioClip_InvokePCMSetPositionCallback_Internal_m986EF703B7DDE42343730DE93A095D05B9F4DBB8 (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, int32_t ___0_position, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_InvokePCMSetPositionCallback_Internal_m986EF703B7DDE42343730DE93A095D05B9F4DBB8_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_position));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClip_InvokePCMSetPositionCallback_Internal_m986EF703B7DDE42343730DE93A095D05B9F4DBB8_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 62));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 63));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 64));
		PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072* L_0 = __this->___m_PCMSetPositionCallback;
		if (!L_0)
		{
			goto IL_0014;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 65));
		PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072* L_1 = __this->___m_PCMSetPositionCallback;
		int32_t L_2 = ___0_position;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 66));
		NullCheck(L_1);
		PCMSetPositionCallback_Invoke_m434D4F02FA25F91DF6199EC5A799C551C7F93702_inline(L_1, L_2, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 66));
	}

IL_0014:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 67));
		return;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void AudioClip_CheckIsNotPersistent_m9792AEB282CC66210DDB73702C33EF5FC001313C (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_CheckIsNotPersistent_m9792AEB282CC66210DDB73702C33EF5FC001313C_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClip_CheckIsNotPersistent_m9792AEB282CC66210DDB73702C33EF5FC001313C_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 68));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 69));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 70));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 71));
		bool L_0;
		L_0 = AudioClip_IsLegacyFormat_m3DB8BD55B7C96596B031D7E2AE5B430C00CE4D58(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 71));
		if (!L_0)
		{
			goto IL_0023;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 72));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 73));
		String_t* L_1;
		L_1 = Object_get_name_mAC2F6B897CF1303BA4249B4CB55271AFACBB6392(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 73));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 74));
		String_t* L_2;
		L_2 = String_Concat_m8855A6DE10F84DA7F4EC113CADDB59873A25573B(((String_t*)il2cpp_codegen_initialize_runtime_metadata_inline((uintptr_t*)&_stringLiteral897119E4E307249E22F47D5E55BF736C2DDC58CE)), L_1, ((String_t*)il2cpp_codegen_initialize_runtime_metadata_inline((uintptr_t*)&_stringLiteralA26BD5C8DBC6B4716A120AC6F43A2DFD1452A36B)), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 74));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 75));
		NotSupportedException_t1429765983D409BD2986508963C98D214E4EBF4A* L_3 = (NotSupportedException_t1429765983D409BD2986508963C98D214E4EBF4A*)il2cpp_codegen_object_new(((RuntimeClass*)il2cpp_codegen_initialize_runtime_metadata_inline((uintptr_t*)&NotSupportedException_t1429765983D409BD2986508963C98D214E4EBF4A_il2cpp_TypeInfo_var)));
		NotSupportedException__ctor_mE174750CF0247BBB47544FFD71D66BB89630945B(L_3, L_2, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 75));
		IL2CPP_RAISE_MANAGED_EXCEPTION(L_3, ((RuntimeMethod*)il2cpp_codegen_initialize_runtime_metadata_inline((uintptr_t*)&AudioClip_CheckIsNotPersistent_m9792AEB282CC66210DDB73702C33EF5FC001313C_RuntimeMethod_var)));
	}

IL_0023:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 76));
		return;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioClip_UnityEngine_Audio_GeneratorInstance_ICapabilities_get_isRealtime_mAC78FD95FB9998B38D0E50C2462DC9D9147FEAA4 (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_UnityEngine_Audio_GeneratorInstance_ICapabilities_get_isRealtime_mAC78FD95FB9998B38D0E50C2462DC9D9147FEAA4_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClip_UnityEngine_Audio_GeneratorInstance_ICapabilities_get_isRealtime_mAC78FD95FB9998B38D0E50C2462DC9D9147FEAA4_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 77));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 78));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 79));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 80));
		AudioClip_CheckIsNotPersistent_m9792AEB282CC66210DDB73702C33EF5FC001313C(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 80));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 81));
		return (bool)0;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioClip_UnityEngine_Audio_GeneratorInstance_ICapabilities_get_isFinite_m20E61329E86505BA44C480115CD9A403FC63308C (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_UnityEngine_Audio_GeneratorInstance_ICapabilities_get_isFinite_m20E61329E86505BA44C480115CD9A403FC63308C_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClip_UnityEngine_Audio_GeneratorInstance_ICapabilities_get_isFinite_m20E61329E86505BA44C480115CD9A403FC63308C_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 82));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 83));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 84));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 85));
		AudioClip_CheckIsNotPersistent_m9792AEB282CC66210DDB73702C33EF5FC001313C(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 85));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 86));
		return (bool)1;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 AudioClip_UnityEngine_Audio_GeneratorInstance_ICapabilities_get_length_mCA231C69B56E93689C2B45DCE2C3F0AD45CF541B (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_UnityEngine_Audio_GeneratorInstance_ICapabilities_get_length_mCA231C69B56E93689C2B45DCE2C3F0AD45CF541B_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E_il2cpp_TypeInfo_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Nullable_1__ctor_mA3535F58A54E060F67F4FFB3A5974A10D6444604_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClip_UnityEngine_Audio_GeneratorInstance_ICapabilities_get_length_mCA231C69B56E93689C2B45DCE2C3F0AD45CF541B_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 87));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 88));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 89));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 90));
		AudioClip_CheckIsNotPersistent_m9792AEB282CC66210DDB73702C33EF5FC001313C(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 90));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 91));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 92));
		int32_t L_0;
		L_0 = AudioClip_get_samples_mDEA01CA75E7DEA0F8D480E4AF97FB96085BCF38E(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 92));
		int64_t L_1 = (il2cpp_codegen_conv<int64_t,int32_t,int32_t,false,false>(L_0,NULL));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 93));
		int32_t L_2;
		L_2 = AudioClip_get_frequency_m6647E10F4B2B1335187B0066E82468CCCF19647B(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 93));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 94));
		int64_t L_3;
		L_3 = Configuration_FramesAndSampleRateToDiscreteTimeTicks_mD8442DC6E7541DA57E38136E474B09FA2A8CC066(L_1, L_2, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 94));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 95));
		il2cpp_codegen_runtime_class_init_inline(DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E_il2cpp_TypeInfo_var);
		DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E L_4;
		L_4 = DiscreteTime_FromTicks_m0AF37F302A6729B9C86ACBBBF3CA26471DF131BC_inline(L_3, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 95));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 96));
		Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 L_5;
		memset((&L_5), 0, sizeof(L_5));
		Nullable_1__ctor_mA3535F58A54E060F67F4FFB3A5974A10D6444604((&L_5), L_4, Nullable_1__ctor_mA3535F58A54E060F67F4FFB3A5974A10D6444604_RuntimeMethod_var);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 96));
		return L_5;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 AudioClip_CreateInstance_m00611E45FCDB4A13BC7A07018E41DFFB4C6DAB73 (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* __this, ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243 ___0_context, Nullable_1_t8743998EB2E7DB936C93772849EF306FBD5C5EE5 ___1_nestedFormat, CreationParameters_tC3AF64A7D0E7DAF87A587B34097DF91B377A9BD7 ___2_creationParameters, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_CreateInstance_m00611E45FCDB4A13BC7A07018E41DFFB4C6DAB73_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioConfigurationU2A_t8DA90320E7ADA7D88875EF03803878B80747E4F4_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GeneratorHeaderU2A_t02B3CDAA7BFFE71942313A5F2CCABF2711EDA5BA_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Nullable_1_get_HasValue_m0A28F36C93C270B2B16241740BA7B9CFE0166F7A_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Nullable_1_get_Value_m32D74DBCABD51FD09C2289F4AB5813C51FD97782_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D* V_0 = NULL;
	GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0* V_1 = NULL;
	AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D V_2;
	memset((&V_2), 0, sizeof(V_2));
	AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D V_3;
	memset((&V_3), 0, sizeof(V_3));
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_context), (&___1_nestedFormat), (&___2_creationParameters));
	DECLARE_METHOD_LOCALS(methodExecutionContextLocals, (&V_0), (&V_1), (&V_2));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClip_CreateInstance_m00611E45FCDB4A13BC7A07018E41DFFB4C6DAB73_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, methodExecutionContextLocals);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 97));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 98));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 99));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 100));
		AudioClip_CheckIsNotPersistent_m9792AEB282CC66210DDB73702C33EF5FC001313C(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 100));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 101));
		uintptr_t L_0 = (il2cpp_codegen_conv<uintptr_t,int32_t,int32_t,false,false>(0,NULL));
		V_0 = (AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D*)L_0;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 102));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 103));
		bool L_1;
		L_1 = Nullable_1_get_HasValue_m0A28F36C93C270B2B16241740BA7B9CFE0166F7A_inline((&___1_nestedFormat), Nullable_1_get_HasValue_m0A28F36C93C270B2B16241740BA7B9CFE0166F7A_RuntimeMethod_var);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 103));
		if (!L_1)
		{
			goto IL_0026;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 104));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 105));
		AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D L_2;
		L_2 = Nullable_1_get_Value_m32D74DBCABD51FD09C2289F4AB5813C51FD97782((&___1_nestedFormat), Nullable_1_get_Value_m32D74DBCABD51FD09C2289F4AB5813C51FD97782_RuntimeMethod_var);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 105));
		V_3 = L_2;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 106));
		AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D L_3;
		L_3 = AudioFormat_get_audioConfiguration_m769CBA67D62C1D12FBE6C55DC2429D62BA135D43_inline((&V_3), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 106));
		V_2 = L_3;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 107));
		uintptr_t L_4 = (il2cpp_codegen_conv<uintptr_t,AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D*,intptr_t,false,false>((&V_2),NULL));
		V_0 = (AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D*)L_4;
	}

IL_0026:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 108));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 109));
		ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* L_5;
		L_5 = ControlContext_get_Header_m48ED40585DBA374B2750157BEFD1A0DC92B654E2_inline((&___0_context), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 109));
		AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D* L_6 = V_0;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 110));
		void* L_7;
		L_7 = SampleProviderBindings_CreateGeneratorHeader_m431C7ACC029F1B61B5C7C81F894FED9AA6C5F640(__this, (void*)L_5, L_6, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 110));
		V_1 = (GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0*)L_7;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 111));
		GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0* L_8 = V_1;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 112));
		GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 L_9;
		memset((&L_9), 0, sizeof(L_9));
		GeneratorInstance__ctor_m918C508DE9944B098D0305A557F6BDC7227C3518((&L_9), L_8, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 112));
		return L_9;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioClip_IsLegacyFormat_Injected_m7072F5FDC54820CA887B98DF51BB23B5AB29D751 (intptr_t ___0__unity_self, const RuntimeMethod* method) 
{
	typedef bool (*AudioClip_IsLegacyFormat_Injected_m7072F5FDC54820CA887B98DF51BB23B5AB29D751_ftn) (intptr_t);
	static AudioClip_IsLegacyFormat_Injected_m7072F5FDC54820CA887B98DF51BB23B5AB29D751_ftn _il2cpp_icall_func;
	if (!_il2cpp_icall_func)
	_il2cpp_icall_func = (AudioClip_IsLegacyFormat_Injected_m7072F5FDC54820CA887B98DF51BB23B5AB29D751_ftn)il2cpp_codegen_resolve_icall ("UnityEngine.AudioClip::IsLegacyFormat_Injected(System.IntPtr)");
	bool icallRetVal = _il2cpp_icall_func(___0__unity_self);
	return icallRetVal;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t AudioClip_get_samples_Injected_m18E5C4BD533706C80A8780D7439E151E305479F5 (intptr_t ___0__unity_self, const RuntimeMethod* method) 
{
	typedef int32_t (*AudioClip_get_samples_Injected_m18E5C4BD533706C80A8780D7439E151E305479F5_ftn) (intptr_t);
	static AudioClip_get_samples_Injected_m18E5C4BD533706C80A8780D7439E151E305479F5_ftn _il2cpp_icall_func;
	if (!_il2cpp_icall_func)
	_il2cpp_icall_func = (AudioClip_get_samples_Injected_m18E5C4BD533706C80A8780D7439E151E305479F5_ftn)il2cpp_codegen_resolve_icall ("UnityEngine.AudioClip::get_samples_Injected(System.IntPtr)");
	int32_t icallRetVal = _il2cpp_icall_func(___0__unity_self);
	return icallRetVal;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t AudioClip_get_frequency_Injected_m88A5AA18CEDCC1F528AF69A95C23ED5ADD39136B (intptr_t ___0__unity_self, const RuntimeMethod* method) 
{
	typedef int32_t (*AudioClip_get_frequency_Injected_m88A5AA18CEDCC1F528AF69A95C23ED5ADD39136B_ftn) (intptr_t);
	static AudioClip_get_frequency_Injected_m88A5AA18CEDCC1F528AF69A95C23ED5ADD39136B_ftn _il2cpp_icall_func;
	if (!_il2cpp_icall_func)
	_il2cpp_icall_func = (AudioClip_get_frequency_Injected_m88A5AA18CEDCC1F528AF69A95C23ED5ADD39136B_ftn)il2cpp_codegen_resolve_icall ("UnityEngine.AudioClip::get_frequency_Injected(System.IntPtr)");
	int32_t icallRetVal = _il2cpp_icall_func(___0__unity_self);
	return icallRetVal;
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
void PCMReaderCallback_Invoke_m76784C690C36B513E2AA5B0E4FD9831B2C7E5152_Multicast(PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E* __this, SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C* ___0_data, const RuntimeMethod* method)
{
	il2cpp_array_size_t length = __this->___delegates->max_length;
	Delegate_t** delegatesToInvoke = reinterpret_cast<Delegate_t**>(__this->___delegates->GetAddressAtUnchecked(0));
	for (il2cpp_array_size_t i = 0; i < length; i++)
	{
		PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E* currentDelegate = reinterpret_cast<PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E*>(delegatesToInvoke[i]);
		typedef void (*FunctionPointerType) (RuntimeObject*, SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C*, const RuntimeMethod*);
		((FunctionPointerType)currentDelegate->___invoke_impl)((Il2CppObject*)currentDelegate->___method_code, ___0_data, reinterpret_cast<RuntimeMethod*>(currentDelegate->___method));
	}
}
void PCMReaderCallback_Invoke_m76784C690C36B513E2AA5B0E4FD9831B2C7E5152_OpenInst(PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E* __this, SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C* ___0_data, const RuntimeMethod* method)
{
	NullCheck(___0_data);
	typedef void (*FunctionPointerType) (SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C*, const RuntimeMethod*);
	((FunctionPointerType)__this->___method_ptr)(___0_data, method);
}
void PCMReaderCallback_Invoke_m76784C690C36B513E2AA5B0E4FD9831B2C7E5152_OpenStatic(PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E* __this, SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C* ___0_data, const RuntimeMethod* method)
{
	typedef void (*FunctionPointerType) (SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C*, const RuntimeMethod*);
	((FunctionPointerType)__this->___method_ptr)(___0_data, method);
}
IL2CPP_EXTERN_C  void DelegatePInvokeWrapper_PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E (PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E* __this, SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C* ___0_data, const RuntimeMethod* method)
{
	typedef void (DEFAULT_CALL *PInvokeFunc)(float*);
	PInvokeFunc il2cppPInvokeFunc = reinterpret_cast<PInvokeFunc>(il2cpp_codegen_get_reverse_pinvoke_function_ptr(__this));
	float* ____0_data_marshaled = NULL;
	if (___0_data != NULL)
	{
		____0_data_marshaled = reinterpret_cast<float*>((___0_data)->GetAddressAtUnchecked(0));
	}

	il2cppPInvokeFunc(____0_data_marshaled);

}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void PCMReaderCallback__ctor_mF621B6CC1A4BA6525190C5037401CF2FD5C0CF28 (PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E* __this, RuntimeObject* ___0_object, intptr_t ___1_method, const RuntimeMethod* method) 
{
	__this->___method_ptr = (intptr_t)il2cpp_codegen_get_method_pointer((RuntimeMethod*)___1_method);
	__this->___method = ___1_method;
	__this->___m_target = ___0_object;
	Il2CppCodeGenWriteBarrier((void**)(&__this->___m_target), (void*)___0_object);
	int parameterCount = il2cpp_codegen_method_parameter_count((RuntimeMethod*)___1_method);
	__this->___method_code = (intptr_t)__this;
	if (MethodIsStatic((RuntimeMethod*)___1_method))
	{
		bool isOpen = parameterCount == 1;
		if (isOpen)
			__this->___invoke_impl = (intptr_t)&PCMReaderCallback_Invoke_m76784C690C36B513E2AA5B0E4FD9831B2C7E5152_OpenStatic;
		else
			{
				__this->___invoke_impl = __this->___method_ptr;
				__this->___method_code = (intptr_t)__this->___m_target;
			}
	}
	else
	{
		bool isOpen = parameterCount == 0;
		if (isOpen)
		{
			__this->___invoke_impl = (intptr_t)&PCMReaderCallback_Invoke_m76784C690C36B513E2AA5B0E4FD9831B2C7E5152_OpenInst;
		}
		else
		{
			if (___0_object == NULL)
				il2cpp_codegen_raise_exception(il2cpp_codegen_get_argument_exception(NULL, "Delegate to an instance method cannot have null 'this'."), NULL);
			__this->___invoke_impl = __this->___method_ptr;
			__this->___method_code = (intptr_t)__this->___m_target;
		}
	}
	__this->___extra_arg = (intptr_t)&PCMReaderCallback_Invoke_m76784C690C36B513E2AA5B0E4FD9831B2C7E5152_Multicast;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void PCMReaderCallback_Invoke_m76784C690C36B513E2AA5B0E4FD9831B2C7E5152 (PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E* __this, SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C* ___0_data, const RuntimeMethod* method) 
{
	typedef void (*FunctionPointerType) (RuntimeObject*, SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C*, const RuntimeMethod*);
	((FunctionPointerType)__this->___invoke_impl)((Il2CppObject*)__this->___method_code, ___0_data, reinterpret_cast<RuntimeMethod*>(__this->___method));
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
void PCMSetPositionCallback_Invoke_m434D4F02FA25F91DF6199EC5A799C551C7F93702_Multicast(PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072* __this, int32_t ___0_position, const RuntimeMethod* method)
{
	il2cpp_array_size_t length = __this->___delegates->max_length;
	Delegate_t** delegatesToInvoke = reinterpret_cast<Delegate_t**>(__this->___delegates->GetAddressAtUnchecked(0));
	for (il2cpp_array_size_t i = 0; i < length; i++)
	{
		PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072* currentDelegate = reinterpret_cast<PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072*>(delegatesToInvoke[i]);
		typedef void (*FunctionPointerType) (RuntimeObject*, int32_t, const RuntimeMethod*);
		((FunctionPointerType)currentDelegate->___invoke_impl)((Il2CppObject*)currentDelegate->___method_code, ___0_position, reinterpret_cast<RuntimeMethod*>(currentDelegate->___method));
	}
}
void PCMSetPositionCallback_Invoke_m434D4F02FA25F91DF6199EC5A799C551C7F93702_OpenInst(PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072* __this, int32_t ___0_position, const RuntimeMethod* method)
{
	typedef void (*FunctionPointerType) (int32_t, const RuntimeMethod*);
	((FunctionPointerType)__this->___method_ptr)(___0_position, method);
}
void PCMSetPositionCallback_Invoke_m434D4F02FA25F91DF6199EC5A799C551C7F93702_OpenStatic(PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072* __this, int32_t ___0_position, const RuntimeMethod* method)
{
	typedef void (*FunctionPointerType) (int32_t, const RuntimeMethod*);
	((FunctionPointerType)__this->___method_ptr)(___0_position, method);
}
IL2CPP_EXTERN_C  void DelegatePInvokeWrapper_PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072 (PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072* __this, int32_t ___0_position, const RuntimeMethod* method)
{
	typedef void (DEFAULT_CALL *PInvokeFunc)(int32_t);
	PInvokeFunc il2cppPInvokeFunc = reinterpret_cast<PInvokeFunc>(il2cpp_codegen_get_reverse_pinvoke_function_ptr(__this));
	il2cppPInvokeFunc(___0_position);

}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void PCMSetPositionCallback__ctor_mD16F77DDB552EB69BB3F5EF39420B2F09F95455B (PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072* __this, RuntimeObject* ___0_object, intptr_t ___1_method, const RuntimeMethod* method) 
{
	__this->___method_ptr = (intptr_t)il2cpp_codegen_get_method_pointer((RuntimeMethod*)___1_method);
	__this->___method = ___1_method;
	__this->___m_target = ___0_object;
	Il2CppCodeGenWriteBarrier((void**)(&__this->___m_target), (void*)___0_object);
	int parameterCount = il2cpp_codegen_method_parameter_count((RuntimeMethod*)___1_method);
	__this->___method_code = (intptr_t)__this;
	if (MethodIsStatic((RuntimeMethod*)___1_method))
	{
		bool isOpen = parameterCount == 1;
		if (isOpen)
			__this->___invoke_impl = (intptr_t)&PCMSetPositionCallback_Invoke_m434D4F02FA25F91DF6199EC5A799C551C7F93702_OpenStatic;
		else
			{
				__this->___invoke_impl = __this->___method_ptr;
				__this->___method_code = (intptr_t)__this->___m_target;
			}
	}
	else
	{
		if (___0_object == NULL)
			il2cpp_codegen_raise_exception(il2cpp_codegen_get_argument_exception(NULL, "Delegate to an instance method cannot have null 'this'."), NULL);
		__this->___invoke_impl = __this->___method_ptr;
		__this->___method_code = (intptr_t)__this->___m_target;
	}
	__this->___extra_arg = (intptr_t)&PCMSetPositionCallback_Invoke_m434D4F02FA25F91DF6199EC5A799C551C7F93702_Multicast;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void PCMSetPositionCallback_Invoke_m434D4F02FA25F91DF6199EC5A799C551C7F93702 (PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072* __this, int32_t ___0_position, const RuntimeMethod* method) 
{
	typedef void (*FunctionPointerType) (RuntimeObject*, int32_t, const RuntimeMethod*);
	((FunctionPointerType)__this->___invoke_impl)((Il2CppObject*)__this->___method_code, ___0_position, reinterpret_cast<RuntimeMethod*>(__this->___method));
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C void WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshal_pinvoke(const WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C& unmarshaled, WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshaled_pinvoke& marshaled)
{
	marshaled.___m_Name = il2cpp_codegen_marshal_string(unmarshaled.___m_Name);
	marshaled.___m_DepthCameraName = il2cpp_codegen_marshal_string(unmarshaled.___m_DepthCameraName);
	marshaled.___m_Flags = unmarshaled.___m_Flags;
	marshaled.___m_Kind = unmarshaled.___m_Kind;
	if (unmarshaled.___m_Resolutions != NULL)
	{
		il2cpp_array_size_t _unmarshaledm_Resolutions_Length = (unmarshaled.___m_Resolutions)->max_length;
		marshaled.___m_Resolutions = il2cpp_codegen_marshal_allocate_array<Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525>(_unmarshaledm_Resolutions_Length);
		for (int32_t i = 0; i < ARRAY_LENGTH_AS_INT32(_unmarshaledm_Resolutions_Length); i++)
		{
			(marshaled.___m_Resolutions)[i] = (unmarshaled.___m_Resolutions)->GetAtUnchecked(static_cast<il2cpp_array_size_t>(i));
		}
	}
	else
	{
		marshaled.___m_Resolutions = NULL;
	}
}
IL2CPP_EXTERN_C void WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshal_pinvoke_back(const WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshaled_pinvoke& marshaled, WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C& unmarshaled)
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	unmarshaled.___m_Name = il2cpp_codegen_marshal_string_result(marshaled.___m_Name);
	Il2CppCodeGenWriteBarrier((void**)(&unmarshaled.___m_Name), (void*)il2cpp_codegen_marshal_string_result(marshaled.___m_Name));
	unmarshaled.___m_DepthCameraName = il2cpp_codegen_marshal_string_result(marshaled.___m_DepthCameraName);
	Il2CppCodeGenWriteBarrier((void**)(&unmarshaled.___m_DepthCameraName), (void*)il2cpp_codegen_marshal_string_result(marshaled.___m_DepthCameraName));
	int32_t unmarshaledm_Flags_temp_2 = 0;
	unmarshaledm_Flags_temp_2 = marshaled.___m_Flags;
	unmarshaled.___m_Flags = unmarshaledm_Flags_temp_2;
	int32_t unmarshaledm_Kind_temp_3 = 0;
	unmarshaledm_Kind_temp_3 = marshaled.___m_Kind;
	unmarshaled.___m_Kind = unmarshaledm_Kind_temp_3;
	if (marshaled.___m_Resolutions != NULL)
	{
		if (unmarshaled.___m_Resolutions == NULL)
		{
			unmarshaled.___m_Resolutions = reinterpret_cast<ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A*>((ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A*)SZArrayNew(ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A_il2cpp_TypeInfo_var, 1));
			Il2CppCodeGenWriteBarrier((void**)(&unmarshaled.___m_Resolutions), (void*)reinterpret_cast<ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A*>((ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A*)SZArrayNew(ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A_il2cpp_TypeInfo_var, 1)));
		}
		il2cpp_array_size_t _arrayLength = (unmarshaled.___m_Resolutions)->max_length;
		for (int32_t i = 0; i < ARRAY_LENGTH_AS_INT32(_arrayLength); i++)
		{
			(unmarshaled.___m_Resolutions)->SetAtUnchecked(static_cast<il2cpp_array_size_t>(i), (marshaled.___m_Resolutions)[i]);
		}
	}
}
IL2CPP_EXTERN_C void WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshal_pinvoke_cleanup(WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshaled_pinvoke& marshaled)
{
	il2cpp_codegen_marshal_free(marshaled.___m_Name);
	marshaled.___m_Name = NULL;
	il2cpp_codegen_marshal_free(marshaled.___m_DepthCameraName);
	marshaled.___m_DepthCameraName = NULL;
	if (marshaled.___m_Resolutions != NULL)
	{
		il2cpp_codegen_marshal_free(marshaled.___m_Resolutions);
		marshaled.___m_Resolutions = NULL;
	}
}
IL2CPP_EXTERN_C void WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshal_com(const WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C& unmarshaled, WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshaled_com& marshaled)
{
	marshaled.___m_Name = il2cpp_codegen_marshal_bstring(unmarshaled.___m_Name);
	marshaled.___m_DepthCameraName = il2cpp_codegen_marshal_bstring(unmarshaled.___m_DepthCameraName);
	marshaled.___m_Flags = unmarshaled.___m_Flags;
	marshaled.___m_Kind = unmarshaled.___m_Kind;
	if (unmarshaled.___m_Resolutions != NULL)
	{
		il2cpp_array_size_t _unmarshaledm_Resolutions_Length = (unmarshaled.___m_Resolutions)->max_length;
		marshaled.___m_Resolutions = il2cpp_codegen_marshal_allocate_array<Resolution_tDF215F567EEFFD07B9A8FB7CEACC08EA6B8B9525>(_unmarshaledm_Resolutions_Length);
		for (int32_t i = 0; i < ARRAY_LENGTH_AS_INT32(_unmarshaledm_Resolutions_Length); i++)
		{
			(marshaled.___m_Resolutions)[i] = (unmarshaled.___m_Resolutions)->GetAtUnchecked(static_cast<il2cpp_array_size_t>(i));
		}
	}
	else
	{
		marshaled.___m_Resolutions = NULL;
	}
}
IL2CPP_EXTERN_C void WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshal_com_back(const WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshaled_com& marshaled, WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C& unmarshaled)
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	unmarshaled.___m_Name = il2cpp_codegen_marshal_bstring_result(marshaled.___m_Name);
	Il2CppCodeGenWriteBarrier((void**)(&unmarshaled.___m_Name), (void*)il2cpp_codegen_marshal_bstring_result(marshaled.___m_Name));
	unmarshaled.___m_DepthCameraName = il2cpp_codegen_marshal_bstring_result(marshaled.___m_DepthCameraName);
	Il2CppCodeGenWriteBarrier((void**)(&unmarshaled.___m_DepthCameraName), (void*)il2cpp_codegen_marshal_bstring_result(marshaled.___m_DepthCameraName));
	int32_t unmarshaledm_Flags_temp_2 = 0;
	unmarshaledm_Flags_temp_2 = marshaled.___m_Flags;
	unmarshaled.___m_Flags = unmarshaledm_Flags_temp_2;
	int32_t unmarshaledm_Kind_temp_3 = 0;
	unmarshaledm_Kind_temp_3 = marshaled.___m_Kind;
	unmarshaled.___m_Kind = unmarshaledm_Kind_temp_3;
	if (marshaled.___m_Resolutions != NULL)
	{
		if (unmarshaled.___m_Resolutions == NULL)
		{
			unmarshaled.___m_Resolutions = reinterpret_cast<ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A*>((ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A*)SZArrayNew(ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A_il2cpp_TypeInfo_var, 1));
			Il2CppCodeGenWriteBarrier((void**)(&unmarshaled.___m_Resolutions), (void*)reinterpret_cast<ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A*>((ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A*)SZArrayNew(ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A_il2cpp_TypeInfo_var, 1)));
		}
		il2cpp_array_size_t _arrayLength = (unmarshaled.___m_Resolutions)->max_length;
		for (int32_t i = 0; i < ARRAY_LENGTH_AS_INT32(_arrayLength); i++)
		{
			(unmarshaled.___m_Resolutions)->SetAtUnchecked(static_cast<il2cpp_array_size_t>(i), (marshaled.___m_Resolutions)[i]);
		}
	}
}
IL2CPP_EXTERN_C void WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshal_com_cleanup(WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_marshaled_com& marshaled)
{
	il2cpp_codegen_marshal_free_bstring(marshaled.___m_Name);
	marshaled.___m_Name = NULL;
	il2cpp_codegen_marshal_free_bstring(marshaled.___m_DepthCameraName);
	marshaled.___m_DepthCameraName = NULL;
	if (marshaled.___m_Resolutions != NULL)
	{
		il2cpp_codegen_marshal_free(marshaled.___m_Resolutions);
		marshaled.___m_Resolutions = NULL;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void WebCamDevice_ReconstructArrayElementRaw_m6B898336095C8CFC6B06E150C17D25621A914CC7 (WebCamDeviceU5BU5D_tA5B1352BDE6FE233B66C3ABF96E00EB3215629F5* ___0_array, int32_t ___1_i, RuntimeObject* ___2_name, RuntimeObject* ___3_depthCameraName, int32_t ___4_flags, int32_t ___5_kind, ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A* ___6_resolutions, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&WebCamDevice_ReconstructArrayElementRaw_m6B898336095C8CFC6B06E150C17D25621A914CC7_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C V_0;
	memset((&V_0), 0, sizeof(V_0));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_array), (&___1_i), (&___2_name), (&___3_depthCameraName), (&___4_flags), (&___5_kind), (&___6_resolutions));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, WebCamDevice_ReconstructArrayElementRaw_m6B898336095C8CFC6B06E150C17D25621A914CC7_RuntimeMethod_var, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 113));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 114));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 115));
		WebCamDeviceU5BU5D_tA5B1352BDE6FE233B66C3ABF96E00EB3215629F5* L_0 = ___0_array;
		int32_t L_1 = ___1_i;
		il2cpp_codegen_initobj((&V_0), sizeof(WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C));
		RuntimeObject* L_2 = ___2_name;
		(&V_0)->___m_Name = ((String_t*)CastclassSealed((RuntimeObject*)L_2, il2cpp_defaults.string_class));
		Il2CppCodeGenWriteBarrier((void**)(&(&V_0)->___m_Name), (void*)((String_t*)CastclassSealed((RuntimeObject*)L_2, il2cpp_defaults.string_class)));
		RuntimeObject* L_3 = ___3_depthCameraName;
		(&V_0)->___m_DepthCameraName = ((String_t*)CastclassSealed((RuntimeObject*)L_3, il2cpp_defaults.string_class));
		Il2CppCodeGenWriteBarrier((void**)(&(&V_0)->___m_DepthCameraName), (void*)((String_t*)CastclassSealed((RuntimeObject*)L_3, il2cpp_defaults.string_class)));
		int32_t L_4 = ___4_flags;
		(&V_0)->___m_Flags = L_4;
		int32_t L_5 = ___5_kind;
		(&V_0)->___m_Kind = L_5;
		ResolutionU5BU5D_t943BB1FE2B73E9E630A701D55F4C6EED8B54175A* L_6 = ___6_resolutions;
		(&V_0)->___m_Resolutions = L_6;
		Il2CppCodeGenWriteBarrier((void**)(&(&V_0)->___m_Resolutions), (void*)L_6);
		WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C L_7 = V_0;
		NullCheck(L_0);
		(L_0)->SetAt(static_cast<il2cpp_array_size_t>(L_1), (WebCamDevice_t3D72A89B7F52FD27192023A67254D19E89D9738C)L_7);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 116));
		return;
	}
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void AudioSampleProvider_InvokeSampleFramesAvailable_mEB16F7230AB65A3576BF053AC5719F8E134FBCD4 (AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2* __this, int32_t ___0_sampleFrameCount, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioSampleProvider_InvokeSampleFramesAvailable_mEB16F7230AB65A3576BF053AC5719F8E134FBCD4_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_sampleFrameCount));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioSampleProvider_InvokeSampleFramesAvailable_mEB16F7230AB65A3576BF053AC5719F8E134FBCD4_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 117));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 118));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 119));
		SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* L_0 = __this->___sampleFramesAvailable;
		if (!L_0)
		{
			goto IL_0015;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 120));
		SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* L_1 = __this->___sampleFramesAvailable;
		int32_t L_2 = ___0_sampleFrameCount;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 121));
		NullCheck(L_1);
		SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_inline(L_1, __this, L_2, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 121));
	}

IL_0015:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 122));
		return;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void AudioSampleProvider_InvokeSampleFramesOverflow_m66593173A527981F5EB2A5EF77B0C9119DAB5E15 (AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2* __this, int32_t ___0_droppedSampleFrameCount, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioSampleProvider_InvokeSampleFramesOverflow_m66593173A527981F5EB2A5EF77B0C9119DAB5E15_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_droppedSampleFrameCount));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioSampleProvider_InvokeSampleFramesOverflow_m66593173A527981F5EB2A5EF77B0C9119DAB5E15_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 123));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 124));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 125));
		SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* L_0 = __this->___sampleFramesOverflow;
		if (!L_0)
		{
			goto IL_0015;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 126));
		SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* L_1 = __this->___sampleFramesOverflow;
		int32_t L_2 = ___0_droppedSampleFrameCount;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 127));
		NullCheck(L_1);
		SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_inline(L_1, __this, L_2, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 127));
	}

IL_0015:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 128));
		return;
	}
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
void SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_Multicast(SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* __this, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2* ___0_provider, uint32_t ___1_sampleFrameCount, const RuntimeMethod* method)
{
	il2cpp_array_size_t length = __this->___delegates->max_length;
	Delegate_t** delegatesToInvoke = reinterpret_cast<Delegate_t**>(__this->___delegates->GetAddressAtUnchecked(0));
	for (il2cpp_array_size_t i = 0; i < length; i++)
	{
		SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* currentDelegate = reinterpret_cast<SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30*>(delegatesToInvoke[i]);
		typedef void (*FunctionPointerType) (RuntimeObject*, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2*, uint32_t, const RuntimeMethod*);
		((FunctionPointerType)currentDelegate->___invoke_impl)((Il2CppObject*)currentDelegate->___method_code, ___0_provider, ___1_sampleFrameCount, reinterpret_cast<RuntimeMethod*>(currentDelegate->___method));
	}
}
void SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_OpenInst(SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* __this, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2* ___0_provider, uint32_t ___1_sampleFrameCount, const RuntimeMethod* method)
{
	NullCheck(___0_provider);
	typedef void (*FunctionPointerType) (AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2*, uint32_t, const RuntimeMethod*);
	((FunctionPointerType)__this->___method_ptr)(___0_provider, ___1_sampleFrameCount, method);
}
void SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_OpenStatic(SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* __this, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2* ___0_provider, uint32_t ___1_sampleFrameCount, const RuntimeMethod* method)
{
	typedef void (*FunctionPointerType) (AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2*, uint32_t, const RuntimeMethod*);
	((FunctionPointerType)__this->___method_ptr)(___0_provider, ___1_sampleFrameCount, method);
}
void SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_OpenVirtual(SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* __this, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2* ___0_provider, uint32_t ___1_sampleFrameCount, const RuntimeMethod* method)
{
	NullCheck(___0_provider);
	VirtualActionInvoker1< uint32_t >::Invoke(il2cpp_codegen_method_get_slot(method), ___0_provider, ___1_sampleFrameCount);
}
void SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_OpenInterface(SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* __this, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2* ___0_provider, uint32_t ___1_sampleFrameCount, const RuntimeMethod* method)
{
	NullCheck(___0_provider);
	InterfaceActionInvoker1< uint32_t >::Invoke(il2cpp_codegen_method_get_slot(method), il2cpp_codegen_method_get_declaring_type(method), ___0_provider, ___1_sampleFrameCount);
}
void SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_OpenGenericVirtual(SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* __this, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2* ___0_provider, uint32_t ___1_sampleFrameCount, const RuntimeMethod* method)
{
	NullCheck(___0_provider);
	GenericVirtualActionInvoker1< uint32_t >::Invoke(method, ___0_provider, ___1_sampleFrameCount);
}
void SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_OpenGenericInterface(SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* __this, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2* ___0_provider, uint32_t ___1_sampleFrameCount, const RuntimeMethod* method)
{
	NullCheck(___0_provider);
	GenericInterfaceActionInvoker1< uint32_t >::Invoke(method, ___0_provider, ___1_sampleFrameCount);
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void SampleFramesHandler__ctor_m7DDE0BAD439CD80791140C7D42D661B598A7663A (SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* __this, RuntimeObject* ___0_object, intptr_t ___1_method, const RuntimeMethod* method) 
{
	__this->___method_ptr = (intptr_t)il2cpp_codegen_get_method_pointer((RuntimeMethod*)___1_method);
	__this->___method = ___1_method;
	__this->___m_target = ___0_object;
	Il2CppCodeGenWriteBarrier((void**)(&__this->___m_target), (void*)___0_object);
	int parameterCount = il2cpp_codegen_method_parameter_count((RuntimeMethod*)___1_method);
	__this->___method_code = (intptr_t)__this;
	if (MethodIsStatic((RuntimeMethod*)___1_method))
	{
		bool isOpen = parameterCount == 2;
		if (isOpen)
			__this->___invoke_impl = (intptr_t)&SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_OpenStatic;
		else
			{
				__this->___invoke_impl = __this->___method_ptr;
				__this->___method_code = (intptr_t)__this->___m_target;
			}
	}
	else
	{
		bool isOpen = parameterCount == 1;
		if (isOpen)
		{
			if (__this->___method_is_virtual)
			{
				if (il2cpp_codegen_method_is_generic_instance_method((RuntimeMethod*)___1_method))
					if (il2cpp_codegen_method_is_interface_method((RuntimeMethod*)___1_method))
						__this->___invoke_impl = (intptr_t)&SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_OpenGenericInterface;
					else
						__this->___invoke_impl = (intptr_t)&SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_OpenGenericVirtual;
				else
					if (il2cpp_codegen_method_is_interface_method((RuntimeMethod*)___1_method))
						__this->___invoke_impl = (intptr_t)&SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_OpenInterface;
					else
						__this->___invoke_impl = (intptr_t)&SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_OpenVirtual;
			}
			else
			{
				__this->___invoke_impl = (intptr_t)&SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_OpenInst;
			}
		}
		else
		{
			if (___0_object == NULL)
				il2cpp_codegen_raise_exception(il2cpp_codegen_get_argument_exception(NULL, "Delegate to an instance method cannot have null 'this'."), NULL);
			__this->___invoke_impl = __this->___method_ptr;
			__this->___method_code = (intptr_t)__this->___m_target;
		}
	}
	__this->___extra_arg = (intptr_t)&SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_Multicast;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC (SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* __this, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2* ___0_provider, uint32_t ___1_sampleFrameCount, const RuntimeMethod* method) 
{
	typedef void (*FunctionPointerType) (RuntimeObject*, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2*, uint32_t, const RuntimeMethod*);
	((FunctionPointerType)__this->___invoke_impl)((Il2CppObject*)__this->___method_code, ___0_provider, ___1_sampleFrameCount, reinterpret_cast<RuntimeMethod*>(__this->___method));
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void* SampleProviderBindings_CreateGeneratorHeader_m431C7ACC029F1B61B5C7C81F894FED9AA6C5F640 (AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* ___0_audioClip, void* ___1_resourceHeader, AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D* ___2_nestedConfiguration, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&MarshalledUnityObject_Marshal_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_m4CF5833467B7EAC854506E5E808202FABD1F15CC_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&SampleProviderBindings_CreateGeneratorHeader_m431C7ACC029F1B61B5C7C81F894FED9AA6C5F640_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, SampleProviderBindings_CreateGeneratorHeader_m431C7ACC029F1B61B5C7C81F894FED9AA6C5F640_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_PAUSE_POINT;
	{
		AudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20* L_0 = ___0_audioClip;
		intptr_t L_1;
		L_1 = MarshalledUnityObject_Marshal_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_m4CF5833467B7EAC854506E5E808202FABD1F15CC_inline(L_0, MarshalledUnityObject_Marshal_TisAudioClip_t5D272C4EB4F2D3ED49F1C346DEA373CF6D585F20_m4CF5833467B7EAC854506E5E808202FABD1F15CC_RuntimeMethod_var);
		void* L_2 = ___1_resourceHeader;
		AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D* L_3 = ___2_nestedConfiguration;
		void* L_4;
		L_4 = SampleProviderBindings_CreateGeneratorHeader_Injected_m5BC947EEDEA293BBFD0508BE58B6254B6A49CC4F(L_1, L_2, L_3, NULL);
		return L_4;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void* SampleProviderBindings_CreateGeneratorHeader_Injected_m5BC947EEDEA293BBFD0508BE58B6254B6A49CC4F (intptr_t ___0_audioClip, void* ___1_resourceHeader, AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D* ___2_nestedConfiguration, const RuntimeMethod* method) 
{
	typedef void* (*SampleProviderBindings_CreateGeneratorHeader_Injected_m5BC947EEDEA293BBFD0508BE58B6254B6A49CC4F_ftn) (intptr_t, void*, AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D*);
	static SampleProviderBindings_CreateGeneratorHeader_Injected_m5BC947EEDEA293BBFD0508BE58B6254B6A49CC4F_ftn _il2cpp_icall_func;
	if (!_il2cpp_icall_func)
	_il2cpp_icall_func = (SampleProviderBindings_CreateGeneratorHeader_Injected_m5BC947EEDEA293BBFD0508BE58B6254B6A49CC4F_ftn)il2cpp_codegen_resolve_icall ("UnityEngine.Audio.SampleProviderBindings::CreateGeneratorHeader_Injected(System.IntPtr,System.Void*,UnityEngine.AudioConfiguration*)");
	void* icallRetVal = _il2cpp_icall_func(___0_audioClip, ___1_resourceHeader, ___2_nestedConfiguration);
	return icallRetVal;
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 AudioClipPlayable_GetHandle_mEA1D664328FF9B08E4F7D5EBCD4B51A754D97C44 (AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClipPlayable_GetHandle_mEA1D664328FF9B08E4F7D5EBCD4B51A754D97C44_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClipPlayable_GetHandle_mEA1D664328FF9B08E4F7D5EBCD4B51A754D97C44_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 129));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 130));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 131));
		PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 L_0 = __this->___m_Handle;
		return L_0;
	}
}
IL2CPP_EXTERN_C  PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 AudioClipPlayable_GetHandle_mEA1D664328FF9B08E4F7D5EBCD4B51A754D97C44_AdjustorThunk (RuntimeObject* __this, const RuntimeMethod* method)
{
	AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0>(__this);
	PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 _returnValue;
	_returnValue = AudioClipPlayable_GetHandle_mEA1D664328FF9B08E4F7D5EBCD4B51A754D97C44_inline(_thisAdjusted, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioClipPlayable_Equals_m9C1C75ACBB74FE06AD02BE4643F6EB39413EFF83 (AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0* __this, AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0 ___0_other, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClipPlayable_Equals_m9C1C75ACBB74FE06AD02BE4643F6EB39413EFF83_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_other));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClipPlayable_Equals_m9C1C75ACBB74FE06AD02BE4643F6EB39413EFF83_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 132));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 133));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 134));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 135));
		PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 L_0;
		L_0 = AudioClipPlayable_GetHandle_mEA1D664328FF9B08E4F7D5EBCD4B51A754D97C44_inline(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 135));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 136));
		PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 L_1;
		L_1 = AudioClipPlayable_GetHandle_mEA1D664328FF9B08E4F7D5EBCD4B51A754D97C44_inline((&___0_other), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 136));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 137));
		bool L_2;
		L_2 = PlayableHandle_op_Equality_m0E6C48A28F75A870AC22ADE3BD42F7F70A43C99C(L_0, L_1, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 137));
		return L_2;
	}
}
IL2CPP_EXTERN_C  bool AudioClipPlayable_Equals_m9C1C75ACBB74FE06AD02BE4643F6EB39413EFF83_AdjustorThunk (RuntimeObject* __this, AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0 ___0_other, const RuntimeMethod* method)
{
	AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0>(__this);
	bool _returnValue;
	_returnValue = AudioClipPlayable_Equals_m9C1C75ACBB74FE06AD02BE4643F6EB39413EFF83(_thisAdjusted, ___0_other, method);
	return _returnValue;
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 AudioMixerPlayable_GetHandle_m6C182D9794E901D123223BB57738A302BEAB41FD (AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioMixerPlayable_GetHandle_m6C182D9794E901D123223BB57738A302BEAB41FD_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioMixerPlayable_GetHandle_m6C182D9794E901D123223BB57738A302BEAB41FD_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 138));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 139));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 140));
		PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 L_0 = __this->___m_Handle;
		return L_0;
	}
}
IL2CPP_EXTERN_C  PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 AudioMixerPlayable_GetHandle_m6C182D9794E901D123223BB57738A302BEAB41FD_AdjustorThunk (RuntimeObject* __this, const RuntimeMethod* method)
{
	AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C>(__this);
	PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 _returnValue;
	_returnValue = AudioMixerPlayable_GetHandle_m6C182D9794E901D123223BB57738A302BEAB41FD_inline(_thisAdjusted, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool AudioMixerPlayable_Equals_mDFB945EB48199A338BAD00D40FB8EEC34CF64D57 (AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C* __this, AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C ___0_other, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioMixerPlayable_Equals_mDFB945EB48199A338BAD00D40FB8EEC34CF64D57_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_other));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioMixerPlayable_Equals_mDFB945EB48199A338BAD00D40FB8EEC34CF64D57_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 141));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 142));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 143));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 144));
		PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 L_0;
		L_0 = AudioMixerPlayable_GetHandle_m6C182D9794E901D123223BB57738A302BEAB41FD_inline(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 144));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 145));
		PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 L_1;
		L_1 = AudioMixerPlayable_GetHandle_m6C182D9794E901D123223BB57738A302BEAB41FD_inline((&___0_other), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 145));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 146));
		bool L_2;
		L_2 = PlayableHandle_op_Equality_m0E6C48A28F75A870AC22ADE3BD42F7F70A43C99C(L_0, L_1, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 146));
		return L_2;
	}
}
IL2CPP_EXTERN_C  bool AudioMixerPlayable_Equals_mDFB945EB48199A338BAD00D40FB8EEC34CF64D57_AdjustorThunk (RuntimeObject* __this, AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C ___0_other, const RuntimeMethod* method)
{
	AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C>(__this);
	bool _returnValue;
	_returnValue = AudioMixerPlayable_Equals_mDFB945EB48199A338BAD00D40FB8EEC34CF64D57(_thisAdjusted, ___0_other, method);
	return _returnValue;
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D AudioFormat_get_audioConfiguration_m769CBA67D62C1D12FBE6C55DC2429D62BA135D43 (AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioFormat_get_audioConfiguration_m769CBA67D62C1D12FBE6C55DC2429D62BA135D43_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioFormat_get_audioConfiguration_m769CBA67D62C1D12FBE6C55DC2429D62BA135D43_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 147));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 148));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 149));
		AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D L_0 = __this->___m_Config;
		return L_0;
	}
}
IL2CPP_EXTERN_C  AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D AudioFormat_get_audioConfiguration_m769CBA67D62C1D12FBE6C55DC2429D62BA135D43_AdjustorThunk (RuntimeObject* __this, const RuntimeMethod* method)
{
	AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D>(__this);
	AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D _returnValue;
	_returnValue = AudioFormat_get_audioConfiguration_m769CBA67D62C1D12FBE6C55DC2429D62BA135D43_inline(_thisAdjusted, method);
	return _returnValue;
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* ControlContext_get_Header_m48ED40585DBA374B2750157BEFD1A0DC92B654E2 (ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlContext_get_Header_m48ED40585DBA374B2750157BEFD1A0DC92B654E2_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ControlContext_get_Header_m48ED40585DBA374B2750157BEFD1A0DC92B654E2_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 150));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 151));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 152));
		ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* L_0 = __this->___m_Header;
		return L_0;
	}
}
IL2CPP_EXTERN_C  ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* ControlContext_get_Header_m48ED40585DBA374B2750157BEFD1A0DC92B654E2_AdjustorThunk (RuntimeObject* __this, const RuntimeMethod* method)
{
	ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243>(__this);
	ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* _returnValue;
	_returnValue = ControlContext_get_Header_m48ED40585DBA374B2750157BEFD1A0DC92B654E2_inline(_thisAdjusted, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void ControlContext__ctor_mFFC3A14E72F61DACB51F4F771FAE8416702023B6 (ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* __this, void* ___0_headerThatShouldBeOfResourceType, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlContext__ctor_mFFC3A14E72F61DACB51F4F771FAE8416702023B6_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlHeaderU2A_t829B34D8DC0A755115481A118D668FFD483EEF97_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* V_0 = NULL;
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_headerThatShouldBeOfResourceType));
	DECLARE_METHOD_LOCALS(methodExecutionContextLocals, (&V_0));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ControlContext__ctor_mFFC3A14E72F61DACB51F4F771FAE8416702023B6_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, methodExecutionContextLocals);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 153));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 154));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 155));
		void* L_0 = ___0_headerThatShouldBeOfResourceType;
		V_0 = (ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67*)L_0;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 156));
		ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* L_1 = V_0;
		NullCheck(L_1);
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 L_2 = L_1->___Handle;
		__this->___m_Handle = L_2;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 157));
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* L_3 = (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153*)(&__this->___m_Handle);
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 158));
		Handle_CheckValidOrThrow_mA6C3BAA711CDA462A6A2653A1A2D04CE2AECD3C3(L_3, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 158));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 159));
		ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* L_4 = V_0;
		__this->___m_Header = L_4;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 160));
		return;
	}
}
IL2CPP_EXTERN_C  void ControlContext__ctor_mFFC3A14E72F61DACB51F4F771FAE8416702023B6_AdjustorThunk (RuntimeObject* __this, void* ___0_headerThatShouldBeOfResourceType, const RuntimeMethod* method)
{
	ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243>(__this);
	ControlContext__ctor_mFFC3A14E72F61DACB51F4F771FAE8416702023B6(_thisAdjusted, ___0_headerThatShouldBeOfResourceType, method);
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool ControlContext_Exists_mEEB0CCB244CABE9EAD81EBC5E54CB6B50E18FA0F (ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* __this, ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 ___0_processorInstance, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlContext_Exists_mEEB0CCB244CABE9EAD81EBC5E54CB6B50E18FA0F_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_processorInstance));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ControlContext_Exists_mEEB0CCB244CABE9EAD81EBC5E54CB6B50E18FA0F_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 161));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 162));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 163));
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* L_0 = (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153*)(&__this->___m_Handle);
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 164));
		Handle_CheckValidOrThrow_mA6C3BAA711CDA462A6A2653A1A2D04CE2AECD3C3(L_0, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 164));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 165));
		ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 L_1 = ___0_processorInstance;
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 L_2 = L_1.___Handle;
		ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* L_3 = __this->___m_Header;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 166));
		bool L_4;
		L_4 = ScriptableProcessorBindings_CheckProcessorExists_mCA17BD1A2B9E776034C7B312CA810B3B739AA04E(L_2, L_3, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 166));
		return L_4;
	}
}
IL2CPP_EXTERN_C  bool ControlContext_Exists_mEEB0CCB244CABE9EAD81EBC5E54CB6B50E18FA0F_AdjustorThunk (RuntimeObject* __this, ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 ___0_processorInstance, const RuntimeMethod* method)
{
	ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243>(__this);
	bool _returnValue;
	_returnValue = ControlContext_Exists_mEEB0CCB244CABE9EAD81EBC5E54CB6B50E18FA0F(_thisAdjusted, ___0_processorInstance, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 ControlContext_GetConfiguration_m5EF5175CD07C7E1661F6AC36ECEA52A293DB0249 (ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* __this, GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 ___0_generatorInstance, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlContext_GetConfiguration_m5EF5175CD07C7E1661F6AC36ECEA52A293DB0249_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_generatorInstance));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ControlContext_GetConfiguration_m5EF5175CD07C7E1661F6AC36ECEA52A293DB0249_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 167));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 168));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 169));
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* L_0 = (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153*)(&__this->___m_Handle);
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 170));
		Handle_CheckValidOrThrow_mA6C3BAA711CDA462A6A2653A1A2D04CE2AECD3C3(L_0, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 170));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 171));
		ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* L_1 = (ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35*)(&(&___0_generatorInstance)->___m_ProcessorInstance);
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* L_2 = (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153*)(&L_1->___Handle);
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 172));
		Handle_CheckValidOrThrow_mA6C3BAA711CDA462A6A2653A1A2D04CE2AECD3C3(L_2, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 172));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 173));
		GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 L_3 = ___0_generatorInstance;
		ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 L_4 = L_3.___m_ProcessorInstance;
		ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085* L_5 = L_4.___Header;
		NullCheck(L_5);
		Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 L_6 = ((GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0*)L_5)->___Configuration;
		return L_6;
	}
}
IL2CPP_EXTERN_C  Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 ControlContext_GetConfiguration_m5EF5175CD07C7E1661F6AC36ECEA52A293DB0249_AdjustorThunk (RuntimeObject* __this, GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 ___0_generatorInstance, const RuntimeMethod* method)
{
	ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243>(__this);
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 _returnValue;
	_returnValue = ControlContext_GetConfiguration_m5EF5175CD07C7E1661F6AC36ECEA52A293DB0249(_thisAdjusted, ___0_generatorInstance, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void ControlContext_CleanupHeader_mC560997117E3E82A193438753C1020A76A208F5E (ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* ___0_header, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlContext_CleanupHeader_mC560997117E3E82A193438753C1020A76A208F5E_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GCHandle_tC44F6F72EE68BD4CFABA24309DA7A179D41127DC_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	GCHandle_tC44F6F72EE68BD4CFABA24309DA7A179D41127DC V_0;
	memset((&V_0), 0, sizeof(V_0));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_header));
	DECLARE_METHOD_LOCALS(methodExecutionContextLocals, (&V_0));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ControlContext_CleanupHeader_mC560997117E3E82A193438753C1020A76A208F5E_RuntimeMethod_var, NULL, methodExecutionContextParameters, methodExecutionContextLocals);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 174));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 175));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 176));
		ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* L_0 = ___0_header;
		intptr_t L_1 = L_0->___ManagedTransport;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 177));
		bool L_2;
		L_2 = IntPtr_op_Inequality_m90EFC9C4CAD9A33E309F2DDF98EE4E1DD253637B_inline(L_1, 0, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 177));
		if (!L_2)
		{
			goto IL_002e;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 178));
		ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* L_3 = ___0_header;
		intptr_t L_4 = L_3->___ManagedTransport;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 179));
		GCHandle_tC44F6F72EE68BD4CFABA24309DA7A179D41127DC L_5;
		L_5 = GCHandle_FromIntPtr_mA7848A4285D007CADC52B6272DB243C8FDFD5FAC(L_4, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 179));
		V_0 = L_5;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 180));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 181));
		bool L_6;
		L_6 = GCHandle_get_IsAllocated_m241908103D8D867E11CCAB73C918729825E86843_inline((&V_0), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 181));
		if (!L_6)
		{
			goto IL_002e;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 182));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 183));
		GCHandle_Free_m1320A260E487EB1EA6D95F9E54BFFCB5A4EF83A3((&V_0), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 183));
	}

IL_002e:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 184));
		return;
	}
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 GeneratorInstance_op_Implicit_mB7A6E46130D3BAB42E00F4DD08155EF286A16167 (GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* ___0_generatorInstance, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GeneratorInstance_op_Implicit_mB7A6E46130D3BAB42E00F4DD08155EF286A16167_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_generatorInstance));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, GeneratorInstance_op_Implicit_mB7A6E46130D3BAB42E00F4DD08155EF286A16167_RuntimeMethod_var, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 185));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 186));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 187));
		GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* L_0 = ___0_generatorInstance;
		ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 L_1 = L_0->___m_ProcessorInstance;
		return L_1;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool GeneratorInstance_Equals_m1FEFD7862F181D69396710522A061AA1A5189FE1 (GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* __this, GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 ___0_other, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GeneratorInstance_Equals_m1FEFD7862F181D69396710522A061AA1A5189FE1_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_other));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, GeneratorInstance_Equals_m1FEFD7862F181D69396710522A061AA1A5189FE1_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 188));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 189));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 190));
		ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* L_0 = (ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35*)(&__this->___m_ProcessorInstance);
		GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 L_1 = ___0_other;
		ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 L_2 = L_1.___m_ProcessorInstance;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 191));
		bool L_3;
		L_3 = ProcessorInstance_Equals_m4873E7D141484FCADC7F0F9C64542D57E0D02398(L_0, L_2, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 191));
		return L_3;
	}
}
IL2CPP_EXTERN_C  bool GeneratorInstance_Equals_m1FEFD7862F181D69396710522A061AA1A5189FE1_AdjustorThunk (RuntimeObject* __this, GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 ___0_other, const RuntimeMethod* method)
{
	GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2>(__this);
	bool _returnValue;
	_returnValue = GeneratorInstance_Equals_m1FEFD7862F181D69396710522A061AA1A5189FE1(_thisAdjusted, ___0_other, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool GeneratorInstance_Equals_m7412F772B53B5052FF5070FB2BB2099A93270206 (GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* __this, RuntimeObject* ___0_obj, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GeneratorInstance_Equals_m7412F772B53B5052FF5070FB2BB2099A93270206_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 V_0;
	memset((&V_0), 0, sizeof(V_0));
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_obj));
	DECLARE_METHOD_LOCALS(methodExecutionContextLocals, (&V_0));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, GeneratorInstance_Equals_m7412F772B53B5052FF5070FB2BB2099A93270206_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, methodExecutionContextLocals);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 192));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 193));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 194));
		RuntimeObject* L_0 = ___0_obj;
		if (L_0)
		{
			goto IL_0005;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 195));
		return (bool)0;
	}

IL_0005:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 196));
		RuntimeObject* L_1 = ___0_obj;
		if (!((RuntimeObject*)IsInstSealed((RuntimeObject*)L_1, GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2_il2cpp_TypeInfo_var)))
		{
			goto IL_001c;
		}
	}
	{
		RuntimeObject* L_2 = ___0_obj;
		V_0 = ((*(GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2*)UnBox(L_2, GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2_il2cpp_TypeInfo_var)));
		GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 L_3 = V_0;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 197));
		bool L_4;
		L_4 = GeneratorInstance_Equals_m1FEFD7862F181D69396710522A061AA1A5189FE1(__this, L_3, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 197));
		return L_4;
	}

IL_001c:
	{
		return (bool)0;
	}
}
IL2CPP_EXTERN_C  bool GeneratorInstance_Equals_m7412F772B53B5052FF5070FB2BB2099A93270206_AdjustorThunk (RuntimeObject* __this, RuntimeObject* ___0_obj, const RuntimeMethod* method)
{
	GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2>(__this);
	bool _returnValue;
	_returnValue = GeneratorInstance_Equals_m7412F772B53B5052FF5070FB2BB2099A93270206(_thisAdjusted, ___0_obj, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t GeneratorInstance_GetHashCode_mBF9BB29BE3D212AAAEF53A02346FED4B0435C7D2 (GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GeneratorInstance_GetHashCode_mBF9BB29BE3D212AAAEF53A02346FED4B0435C7D2_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, GeneratorInstance_GetHashCode_mBF9BB29BE3D212AAAEF53A02346FED4B0435C7D2_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 198));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 199));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 200));
		ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* L_0 = (ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35*)(&__this->___m_ProcessorInstance);
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 201));
		int32_t L_1;
		L_1 = ProcessorInstance_GetHashCode_m607D39F5BA947B94238348CF61431A9D8049F9B0(L_0, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 201));
		return L_1;
	}
}
IL2CPP_EXTERN_C  int32_t GeneratorInstance_GetHashCode_mBF9BB29BE3D212AAAEF53A02346FED4B0435C7D2_AdjustorThunk (RuntimeObject* __this, const RuntimeMethod* method)
{
	GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2>(__this);
	int32_t _returnValue;
	_returnValue = GeneratorInstance_GetHashCode_mBF9BB29BE3D212AAAEF53A02346FED4B0435C7D2(_thisAdjusted, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void GeneratorInstance__ctor_m918C508DE9944B098D0305A557F6BDC7227C3518 (GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* __this, GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0* ___0_header, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GeneratorInstance__ctor_m918C508DE9944B098D0305A557F6BDC7227C3518_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_header));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, GeneratorInstance__ctor_m918C508DE9944B098D0305A557F6BDC7227C3518_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 202));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 203));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 204));
		GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0* L_0 = ___0_header;
		NullCheck(L_0);
		ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085* L_1 = (ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085*)(&L_0->___Processor);
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 L_2 = L_1->___DualThreadHandle;
		GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0* L_3 = ___0_header;
		NullCheck(L_3);
		ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085* L_4 = (ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085*)(&L_3->___Processor);
		uintptr_t L_5 = (il2cpp_codegen_conv<uintptr_t,ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085*,intptr_t,false,false>(L_4,NULL));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 205));
		ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 L_6;
		memset((&L_6), 0, sizeof(L_6));
		ProcessorInstance__ctor_m3E0B9039361DE404D8DF604C8D6E324B2F6CC36B((&L_6), L_2, (ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085*)L_5, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 205));
		__this->___m_ProcessorInstance = L_6;
		return;
	}
}
IL2CPP_EXTERN_C  void GeneratorInstance__ctor_m918C508DE9944B098D0305A557F6BDC7227C3518_AdjustorThunk (RuntimeObject* __this, GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0* ___0_header, const RuntimeMethod* method)
{
	GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2>(__this);
	GeneratorInstance__ctor_m918C508DE9944B098D0305A557F6BDC7227C3518(_thisAdjusted, ___0_header, method);
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C void Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_pinvoke(const Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060& unmarshaled, Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_pinvoke& marshaled)
{
	marshaled.___Setup = unmarshaled.___Setup;
	marshaled.___Properties = unmarshaled.___Properties;
	marshaled.___ReportedLength = unmarshaled.___ReportedLength;
	marshaled.___IsFinite = static_cast<int32_t>(unmarshaled.___IsFinite);
	marshaled.___IsRealtime = static_cast<int32_t>(unmarshaled.___IsRealtime);
	marshaled.___HasKnownLength = static_cast<int32_t>(unmarshaled.___HasKnownLength);
}
IL2CPP_EXTERN_C void Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_pinvoke_back(const Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_pinvoke& marshaled, Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060& unmarshaled)
{
	Setup_t24BE50E09A2A2C409ED7EC3BCEB0B8ACD458A503 unmarshaledSetup_temp_0;
	memset((&unmarshaledSetup_temp_0), 0, sizeof(unmarshaledSetup_temp_0));
	unmarshaledSetup_temp_0 = marshaled.___Setup;
	unmarshaled.___Setup = unmarshaledSetup_temp_0;
	Properties_tA0A739E222CC4DF46C8E1F08B908950539845092 unmarshaledProperties_temp_1;
	memset((&unmarshaledProperties_temp_1), 0, sizeof(unmarshaledProperties_temp_1));
	unmarshaledProperties_temp_1 = marshaled.___Properties;
	unmarshaled.___Properties = unmarshaledProperties_temp_1;
	DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E unmarshaledReportedLength_temp_2;
	memset((&unmarshaledReportedLength_temp_2), 0, sizeof(unmarshaledReportedLength_temp_2));
	unmarshaledReportedLength_temp_2 = marshaled.___ReportedLength;
	unmarshaled.___ReportedLength = unmarshaledReportedLength_temp_2;
	bool unmarshaledIsFinite_temp_3 = false;
	unmarshaledIsFinite_temp_3 = static_cast<bool>(marshaled.___IsFinite);
	unmarshaled.___IsFinite = unmarshaledIsFinite_temp_3;
	bool unmarshaledIsRealtime_temp_4 = false;
	unmarshaledIsRealtime_temp_4 = static_cast<bool>(marshaled.___IsRealtime);
	unmarshaled.___IsRealtime = unmarshaledIsRealtime_temp_4;
	bool unmarshaledHasKnownLength_temp_5 = false;
	unmarshaledHasKnownLength_temp_5 = static_cast<bool>(marshaled.___HasKnownLength);
	unmarshaled.___HasKnownLength = unmarshaledHasKnownLength_temp_5;
}
IL2CPP_EXTERN_C void Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_pinvoke_cleanup(Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_pinvoke& marshaled)
{
}
IL2CPP_EXTERN_C void Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_com(const Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060& unmarshaled, Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_com& marshaled)
{
	marshaled.___Setup = unmarshaled.___Setup;
	marshaled.___Properties = unmarshaled.___Properties;
	marshaled.___ReportedLength = unmarshaled.___ReportedLength;
	marshaled.___IsFinite = static_cast<int32_t>(unmarshaled.___IsFinite);
	marshaled.___IsRealtime = static_cast<int32_t>(unmarshaled.___IsRealtime);
	marshaled.___HasKnownLength = static_cast<int32_t>(unmarshaled.___HasKnownLength);
}
IL2CPP_EXTERN_C void Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_com_back(const Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_com& marshaled, Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060& unmarshaled)
{
	Setup_t24BE50E09A2A2C409ED7EC3BCEB0B8ACD458A503 unmarshaledSetup_temp_0;
	memset((&unmarshaledSetup_temp_0), 0, sizeof(unmarshaledSetup_temp_0));
	unmarshaledSetup_temp_0 = marshaled.___Setup;
	unmarshaled.___Setup = unmarshaledSetup_temp_0;
	Properties_tA0A739E222CC4DF46C8E1F08B908950539845092 unmarshaledProperties_temp_1;
	memset((&unmarshaledProperties_temp_1), 0, sizeof(unmarshaledProperties_temp_1));
	unmarshaledProperties_temp_1 = marshaled.___Properties;
	unmarshaled.___Properties = unmarshaledProperties_temp_1;
	DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E unmarshaledReportedLength_temp_2;
	memset((&unmarshaledReportedLength_temp_2), 0, sizeof(unmarshaledReportedLength_temp_2));
	unmarshaledReportedLength_temp_2 = marshaled.___ReportedLength;
	unmarshaled.___ReportedLength = unmarshaledReportedLength_temp_2;
	bool unmarshaledIsFinite_temp_3 = false;
	unmarshaledIsFinite_temp_3 = static_cast<bool>(marshaled.___IsFinite);
	unmarshaled.___IsFinite = unmarshaledIsFinite_temp_3;
	bool unmarshaledIsRealtime_temp_4 = false;
	unmarshaledIsRealtime_temp_4 = static_cast<bool>(marshaled.___IsRealtime);
	unmarshaled.___IsRealtime = unmarshaledIsRealtime_temp_4;
	bool unmarshaledHasKnownLength_temp_5 = false;
	unmarshaledHasKnownLength_temp_5 = static_cast<bool>(marshaled.___HasKnownLength);
	unmarshaled.___HasKnownLength = unmarshaledHasKnownLength_temp_5;
}
IL2CPP_EXTERN_C void Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_com_cleanup(Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshaled_com& marshaled)
{
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool Configuration_get_isRealtime_m99E988C200947A8277C144A84CB1755B5A0C2D78 (Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Configuration_get_isRealtime_m99E988C200947A8277C144A84CB1755B5A0C2D78_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Configuration_get_isRealtime_m99E988C200947A8277C144A84CB1755B5A0C2D78_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 206));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 207));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 208));
		bool L_0 = __this->___IsRealtime;
		return L_0;
	}
}
IL2CPP_EXTERN_C  bool Configuration_get_isRealtime_m99E988C200947A8277C144A84CB1755B5A0C2D78_AdjustorThunk (RuntimeObject* __this, const RuntimeMethod* method)
{
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060>(__this);
	bool _returnValue;
	_returnValue = Configuration_get_isRealtime_m99E988C200947A8277C144A84CB1755B5A0C2D78_inline(_thisAdjusted, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 Configuration_get_length_mB699EC1CF6B8A0955A60B55ABB22AD00A3F6BC3B (Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Configuration_get_length_mB699EC1CF6B8A0955A60B55ABB22AD00A3F6BC3B_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Nullable_1__ctor_mA3535F58A54E060F67F4FFB3A5974A10D6444604_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 V_0;
	memset((&V_0), 0, sizeof(V_0));
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Configuration_get_length_mB699EC1CF6B8A0955A60B55ABB22AD00A3F6BC3B_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 209));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 210));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 211));
		bool L_0 = __this->___HasKnownLength;
		if (L_0)
		{
			goto IL_0012;
		}
	}
	{
		il2cpp_codegen_initobj((&V_0), sizeof(Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363));
		Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 L_1 = V_0;
		return L_1;
	}

IL_0012:
	{
		DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E L_2 = __this->___ReportedLength;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 212));
		Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 L_3;
		memset((&L_3), 0, sizeof(L_3));
		Nullable_1__ctor_mA3535F58A54E060F67F4FFB3A5974A10D6444604((&L_3), L_2, Nullable_1__ctor_mA3535F58A54E060F67F4FFB3A5974A10D6444604_RuntimeMethod_var);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 212));
		return L_3;
	}
}
IL2CPP_EXTERN_C  Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 Configuration_get_length_mB699EC1CF6B8A0955A60B55ABB22AD00A3F6BC3B_AdjustorThunk (RuntimeObject* __this, const RuntimeMethod* method)
{
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060>(__this);
	Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 _returnValue;
	_returnValue = Configuration_get_length_mB699EC1CF6B8A0955A60B55ABB22AD00A3F6BC3B(_thisAdjusted, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int64_t Configuration_FramesAndSampleRateToDiscreteTimeTicks_mD8442DC6E7541DA57E38136E474B09FA2A8CC066 (int64_t ___0_lengthFrames, uint32_t ___1_sampleRate, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Configuration_FramesAndSampleRateToDiscreteTimeTicks_mD8442DC6E7541DA57E38136E474B09FA2A8CC066_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_lengthFrames), (&___1_sampleRate));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Configuration_FramesAndSampleRateToDiscreteTimeTicks_mD8442DC6E7541DA57E38136E474B09FA2A8CC066_RuntimeMethod_var, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 213));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 214));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 215));
		uint32_t L_0 = ___1_sampleRate;
		if ((!(((uint32_t)L_0) <= ((uint32_t)((int32_t)44100)))))
		{
			goto IL_0037;
		}
	}
	{
		uint32_t L_1 = ___1_sampleRate;
		if ((!(((uint32_t)L_1) <= ((uint32_t)((int32_t)16000)))))
		{
			goto IL_0025;
		}
	}
	{
		uint32_t L_2 = ___1_sampleRate;
		if ((((int32_t)L_2) == ((int32_t)((int32_t)8000))))
		{
			goto IL_0063;
		}
	}
	{
		uint32_t L_3 = ___1_sampleRate;
		if ((((int32_t)L_3) == ((int32_t)((int32_t)16000))))
		{
			goto IL_006c;
		}
	}
	{
		goto IL_00ab;
	}

IL_0025:
	{
		uint32_t L_4 = ___1_sampleRate;
		if ((((int32_t)L_4) == ((int32_t)((int32_t)22050))))
		{
			goto IL_0075;
		}
	}
	{
		uint32_t L_5 = ___1_sampleRate;
		if ((((int32_t)L_5) == ((int32_t)((int32_t)44100))))
		{
			goto IL_007e;
		}
	}
	{
		goto IL_00ab;
	}

IL_0037:
	{
		uint32_t L_6 = ___1_sampleRate;
		if ((!(((uint32_t)L_6) <= ((uint32_t)((int32_t)88200)))))
		{
			goto IL_0051;
		}
	}
	{
		uint32_t L_7 = ___1_sampleRate;
		if ((((int32_t)L_7) == ((int32_t)((int32_t)48000))))
		{
			goto IL_0087;
		}
	}
	{
		uint32_t L_8 = ___1_sampleRate;
		if ((((int32_t)L_8) == ((int32_t)((int32_t)88200))))
		{
			goto IL_0090;
		}
	}
	{
		goto IL_00ab;
	}

IL_0051:
	{
		uint32_t L_9 = ___1_sampleRate;
		if ((((int32_t)L_9) == ((int32_t)((int32_t)96000))))
		{
			goto IL_0099;
		}
	}
	{
		uint32_t L_10 = ___1_sampleRate;
		if ((((int32_t)L_10) == ((int32_t)((int32_t)192000))))
		{
			goto IL_00a2;
		}
	}
	{
		goto IL_00ab;
	}

IL_0063:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 216));
		int64_t L_11 = ___0_lengthFrames;
		int64_t L_12 = (il2cpp_codegen_conv<int64_t,int32_t,int32_t,false,false>(((int32_t)17640),NULL));
		return ((int64_t)il2cpp_codegen_multiply(L_11, L_12));
	}

IL_006c:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 217));
		int64_t L_13 = ___0_lengthFrames;
		int64_t L_14 = (il2cpp_codegen_conv<int64_t,int32_t,int32_t,false,false>(((int32_t)8820),NULL));
		return ((int64_t)il2cpp_codegen_multiply(L_13, L_14));
	}

IL_0075:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 218));
		int64_t L_15 = ___0_lengthFrames;
		int64_t L_16 = (il2cpp_codegen_conv<int64_t,int32_t,int32_t,false,false>(((int32_t)6400),NULL));
		return ((int64_t)il2cpp_codegen_multiply(L_15, L_16));
	}

IL_007e:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 219));
		int64_t L_17 = ___0_lengthFrames;
		int64_t L_18 = (il2cpp_codegen_conv<int64_t,int32_t,int32_t,false,false>(((int32_t)3200),NULL));
		return ((int64_t)il2cpp_codegen_multiply(L_17, L_18));
	}

IL_0087:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 220));
		int64_t L_19 = ___0_lengthFrames;
		int64_t L_20 = (il2cpp_codegen_conv<int64_t,int32_t,int32_t,false,false>(((int32_t)2940),NULL));
		return ((int64_t)il2cpp_codegen_multiply(L_19, L_20));
	}

IL_0090:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 221));
		int64_t L_21 = ___0_lengthFrames;
		int64_t L_22 = (il2cpp_codegen_conv<int64_t,int32_t,int32_t,false,false>(((int32_t)1600),NULL));
		return ((int64_t)il2cpp_codegen_multiply(L_21, L_22));
	}

IL_0099:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 222));
		int64_t L_23 = ___0_lengthFrames;
		int64_t L_24 = (il2cpp_codegen_conv<int64_t,int32_t,int32_t,false,false>(((int32_t)1470),NULL));
		return ((int64_t)il2cpp_codegen_multiply(L_23, L_24));
	}

IL_00a2:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 223));
		int64_t L_25 = ___0_lengthFrames;
		int64_t L_26 = (il2cpp_codegen_conv<int64_t,int32_t,int32_t,false,false>(((int32_t)735),NULL));
		return ((int64_t)il2cpp_codegen_multiply(L_25, L_26));
	}

IL_00ab:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 224));
		int64_t L_27 = ___0_lengthFrames;
		int64_t L_28 = (il2cpp_codegen_conv<int64_t,int32_t,int32_t,false,false>(((int32_t)141120000),NULL));
		uint32_t L_29 = ___1_sampleRate;
		uint64_t L_30 = (il2cpp_codegen_conv<uint64_t,uint32_t,int32_t,false,false>(L_29,NULL));
		return ((int64_t)(((int64_t)il2cpp_codegen_multiply(L_27, L_28))/(int64_t)L_30));
	}
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif


IL2CPP_EXTERN_C void GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshal_pinvoke(const GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0& unmarshaled, GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshaled_pinvoke& marshaled)
{
	marshaled.___Processor = unmarshaled.___Processor;
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_pinvoke(unmarshaled.___Configuration, marshaled.___Configuration);
}
IL2CPP_EXTERN_C void GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshal_pinvoke_back(const GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshaled_pinvoke& marshaled, GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0& unmarshaled)
{
	ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085 unmarshaledProcessor_temp_0;
	memset((&unmarshaledProcessor_temp_0), 0, sizeof(unmarshaledProcessor_temp_0));
	unmarshaledProcessor_temp_0 = marshaled.___Processor;
	unmarshaled.___Processor = unmarshaledProcessor_temp_0;
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 unmarshaledConfiguration_temp_1;
	memset((&unmarshaledConfiguration_temp_1), 0, sizeof(unmarshaledConfiguration_temp_1));
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_pinvoke_back(marshaled.___Configuration, unmarshaledConfiguration_temp_1);
	unmarshaled.___Configuration = unmarshaledConfiguration_temp_1;
}
IL2CPP_EXTERN_C void GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshal_pinvoke_cleanup(GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshaled_pinvoke& marshaled)
{
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_pinvoke_cleanup(marshaled.___Configuration);
}


IL2CPP_EXTERN_C void GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshal_com(const GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0& unmarshaled, GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshaled_com& marshaled)
{
	marshaled.___Processor = unmarshaled.___Processor;
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_com(unmarshaled.___Configuration, marshaled.___Configuration);
}
IL2CPP_EXTERN_C void GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshal_com_back(const GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshaled_com& marshaled, GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0& unmarshaled)
{
	ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085 unmarshaledProcessor_temp_0;
	memset((&unmarshaledProcessor_temp_0), 0, sizeof(unmarshaledProcessor_temp_0));
	unmarshaledProcessor_temp_0 = marshaled.___Processor;
	unmarshaled.___Processor = unmarshaledProcessor_temp_0;
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 unmarshaledConfiguration_temp_1;
	memset((&unmarshaledConfiguration_temp_1), 0, sizeof(unmarshaledConfiguration_temp_1));
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_com_back(marshaled.___Configuration, unmarshaledConfiguration_temp_1);
	unmarshaled.___Configuration = unmarshaledConfiguration_temp_1;
}
IL2CPP_EXTERN_C void GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshal_com_cleanup(GeneratorHeader_t73B89668B0DA457A4F3141DE6AC8B72D5ED0BDF0_marshaled_com& marshaled)
{
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_marshal_com_cleanup(marshaled.___Configuration);
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool ProcessorInstance_Equals_m4873E7D141484FCADC7F0F9C64542D57E0D02398 (ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* __this, ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 ___0_other, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ProcessorInstance_Equals_m4873E7D141484FCADC7F0F9C64542D57E0D02398_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_other));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ProcessorInstance_Equals_m4873E7D141484FCADC7F0F9C64542D57E0D02398_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 225));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 226));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 227));
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* L_0 = (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153*)(&__this->___Handle);
		ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 L_1 = ___0_other;
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 L_2 = L_1.___Handle;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 228));
		bool L_3;
		L_3 = Handle_Equals_m5D8356E5FCA91FFFEACC910C738C37690EBA2E64(L_0, L_2, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 228));
		return L_3;
	}
}
IL2CPP_EXTERN_C  bool ProcessorInstance_Equals_m4873E7D141484FCADC7F0F9C64542D57E0D02398_AdjustorThunk (RuntimeObject* __this, ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 ___0_other, const RuntimeMethod* method)
{
	ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35>(__this);
	bool _returnValue;
	_returnValue = ProcessorInstance_Equals_m4873E7D141484FCADC7F0F9C64542D57E0D02398(_thisAdjusted, ___0_other, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool ProcessorInstance_Equals_mFE0F0DA5B311AD6D34EABD73F61C4AE3014084ED (ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* __this, RuntimeObject* ___0_obj, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ProcessorInstance_Equals_mFE0F0DA5B311AD6D34EABD73F61C4AE3014084ED_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 V_0;
	memset((&V_0), 0, sizeof(V_0));
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_obj));
	DECLARE_METHOD_LOCALS(methodExecutionContextLocals, (&V_0));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ProcessorInstance_Equals_mFE0F0DA5B311AD6D34EABD73F61C4AE3014084ED_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, methodExecutionContextLocals);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 229));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 230));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 231));
		RuntimeObject* L_0 = ___0_obj;
		if (L_0)
		{
			goto IL_0005;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 232));
		return (bool)0;
	}

IL_0005:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 233));
		RuntimeObject* L_1 = ___0_obj;
		if (!((RuntimeObject*)IsInstSealed((RuntimeObject*)L_1, ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35_il2cpp_TypeInfo_var)))
		{
			goto IL_001c;
		}
	}
	{
		RuntimeObject* L_2 = ___0_obj;
		V_0 = ((*(ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35*)UnBox(L_2, ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35_il2cpp_TypeInfo_var)));
		ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 L_3 = V_0;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 234));
		bool L_4;
		L_4 = ProcessorInstance_Equals_m4873E7D141484FCADC7F0F9C64542D57E0D02398(__this, L_3, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 234));
		return L_4;
	}

IL_001c:
	{
		return (bool)0;
	}
}
IL2CPP_EXTERN_C  bool ProcessorInstance_Equals_mFE0F0DA5B311AD6D34EABD73F61C4AE3014084ED_AdjustorThunk (RuntimeObject* __this, RuntimeObject* ___0_obj, const RuntimeMethod* method)
{
	ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35>(__this);
	bool _returnValue;
	_returnValue = ProcessorInstance_Equals_mFE0F0DA5B311AD6D34EABD73F61C4AE3014084ED(_thisAdjusted, ___0_obj, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t ProcessorInstance_GetHashCode_m607D39F5BA947B94238348CF61431A9D8049F9B0 (ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ProcessorInstance_GetHashCode_m607D39F5BA947B94238348CF61431A9D8049F9B0_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ProcessorInstance_GetHashCode_m607D39F5BA947B94238348CF61431A9D8049F9B0_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 235));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 236));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 237));
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* L_0 = (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153*)(&__this->___Handle);
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 238));
		int32_t L_1;
		L_1 = Handle_GetHashCode_m8DD5E2EE5197C1FF37CD2CF3B4FD892A9E299DFE(L_0, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 238));
		return L_1;
	}
}
IL2CPP_EXTERN_C  int32_t ProcessorInstance_GetHashCode_m607D39F5BA947B94238348CF61431A9D8049F9B0_AdjustorThunk (RuntimeObject* __this, const RuntimeMethod* method)
{
	ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35>(__this);
	int32_t _returnValue;
	_returnValue = ProcessorInstance_GetHashCode_m607D39F5BA947B94238348CF61431A9D8049F9B0(_thisAdjusted, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void ProcessorInstance__ctor_m3E0B9039361DE404D8DF604C8D6E324B2F6CC36B (ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* __this, Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___0_handle, ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085* ___1_header, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ProcessorInstance__ctor_m3E0B9039361DE404D8DF604C8D6E324B2F6CC36B_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_handle), (&___1_header));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ProcessorInstance__ctor_m3E0B9039361DE404D8DF604C8D6E324B2F6CC36B_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 239));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 240));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 241));
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 L_0 = ___0_handle;
		__this->___Handle = L_0;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 242));
		ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085* L_1 = ___1_header;
		__this->___Header = L_1;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 243));
		return;
	}
}
IL2CPP_EXTERN_C  void ProcessorInstance__ctor_m3E0B9039361DE404D8DF604C8D6E324B2F6CC36B_AdjustorThunk (RuntimeObject* __this, Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___0_handle, ProcessorHeader_t2A43F64ECCCC872761CDBE0DA7A36DB193CA1085* ___1_header, const RuntimeMethod* method)
{
	ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35>(__this);
	ProcessorInstance__ctor_m3E0B9039361DE404D8DF604C8D6E324B2F6CC36B(_thisAdjusted, ___0_handle, ___1_header, method);
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void ScriptableGeneratorBindings_InstantiateGeneratorFromObject_m627DB7836271F2551E83B21A49E39952BA58D7B3 (Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C* ___0_generatorObjectDefinition, ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* ___1_control, GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* ___2_runtimeHandle, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlHeaderU2A_t829B34D8DC0A755115481A118D668FFD483EEF97_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&CreationParameters_tC3AF64A7D0E7DAF87A587B34097DF91B377A9BD7_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Debug_t8394C7EEAECA3689C2C9B9DE9C7166D73596276F_il2cpp_TypeInfo_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E_il2cpp_TypeInfo_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&IAudioGenerator_tD9DD08E5891ADC8BBD55CA6E1F00C0EED5C816DA_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&IAudioGenerator_tD9DD08E5891ADC8BBD55CA6E1F00C0EED5C816DA_il2cpp_TypeInfo_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ICapabilities_tF49934ED8BF0930F82A0A54F794949FB61194793_il2cpp_TypeInfo_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Nullable_1_GetValueOrDefault_m5879DF28E8CBC03BD7B2F3A7B383BB0068DE64DC_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Nullable_1_get_HasValue_m2C09C399366A16930BBC996441FE7CED2907D3D0_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Nullable_1_t8743998EB2E7DB936C93772849EF306FBD5C5EE5_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363_il2cpp_TypeInfo_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ScriptableGeneratorBindings_InstantiateGeneratorFromObject_m627DB7836271F2551E83B21A49E39952BA58D7B3_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&_stringLiteral0D4DFFEDA70FA6D865B68C20C1F40F10FC31B6DD);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&_stringLiteral5A10D0C56FEA8FB8816E3E1F6F88D55578F844F7);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&_stringLiteral5C2C12AF4EFFBF824B747CFFBFC316CAE24077D1);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&_stringLiteralC767BA736F2BEEB0EC1BA27ABE77214EC763C9B6);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&_stringLiteralEE560D196E71D95F90A39910549B06428576F27C);
		s_Il2CppMethodInitialized = true;
	}
	RuntimeObject* V_0 = NULL;
	ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* V_1 = NULL;
	ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* V_2 = NULL;
	ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243 V_3;
	memset((&V_3), 0, sizeof(V_3));
	Nullable_1_t8743998EB2E7DB936C93772849EF306FBD5C5EE5 V_4;
	memset((&V_4), 0, sizeof(V_4));
	CreationParameters_tC3AF64A7D0E7DAF87A587B34097DF91B377A9BD7 V_5;
	memset((&V_5), 0, sizeof(V_5));
	Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 V_6;
	memset((&V_6), 0, sizeof(V_6));
	Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 V_7;
	memset((&V_7), 0, sizeof(V_7));
	Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 V_8;
	memset((&V_8), 0, sizeof(V_8));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_generatorObjectDefinition), (&___1_control), (&___2_runtimeHandle));
	DECLARE_METHOD_LOCALS(methodExecutionContextLocals, (&V_0), (&V_1), (&V_3), (&V_6));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ScriptableGeneratorBindings_InstantiateGeneratorFromObject_m627DB7836271F2551E83B21A49E39952BA58D7B3_RuntimeMethod_var, NULL, methodExecutionContextParameters, methodExecutionContextLocals);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 244));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 245));
	int32_t G_B11_0 = 0;
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 246));
		Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C* L_0 = ___0_generatorObjectDefinition;
		V_0 = ((RuntimeObject*)IsInst((RuntimeObject*)L_0, IAudioGenerator_tD9DD08E5891ADC8BBD55CA6E1F00C0EED5C816DA_il2cpp_TypeInfo_var));
		RuntimeObject* L_1 = V_0;
		if (!L_1)
		{
			goto IL_0138;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 247));
		ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* L_2 = ___1_control;
		V_2 = L_2;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 248));
		ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* L_3 = V_2;
		uintptr_t L_4 = (il2cpp_codegen_conv<uintptr_t,ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67*,intptr_t,false,false>(L_3,NULL));
		V_1 = (ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67*)L_4;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 249));
		ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* L_5 = V_1;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 250));
		ControlContext__ctor_mFFC3A14E72F61DACB51F4F771FAE8416702023B6((&V_3), (void*)L_5, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 250));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 251));
		GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* L_6 = ___2_runtimeHandle;
		RuntimeObject* L_7 = V_0;
		ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243 L_8 = V_3;
		il2cpp_codegen_initobj((&V_4), sizeof(Nullable_1_t8743998EB2E7DB936C93772849EF306FBD5C5EE5));
		Nullable_1_t8743998EB2E7DB936C93772849EF306FBD5C5EE5 L_9 = V_4;
		il2cpp_codegen_initobj((&V_5), sizeof(CreationParameters_tC3AF64A7D0E7DAF87A587B34097DF91B377A9BD7));
		CreationParameters_tC3AF64A7D0E7DAF87A587B34097DF91B377A9BD7 L_10 = V_5;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 252));
		NullCheck(L_7);
		GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 L_11;
		L_11 = InterfaceFuncInvoker3< GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2, ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243, Nullable_1_t8743998EB2E7DB936C93772849EF306FBD5C5EE5, CreationParameters_tC3AF64A7D0E7DAF87A587B34097DF91B377A9BD7 >::Invoke(0, IAudioGenerator_tD9DD08E5891ADC8BBD55CA6E1F00C0EED5C816DA_il2cpp_TypeInfo_var, L_7, L_8, L_9, L_10);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 252));
		*(GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2*)L_6 = L_11;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 253));
		GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* L_12 = ___2_runtimeHandle;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 254));
		ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 L_13;
		L_13 = GeneratorInstance_op_Implicit_mB7A6E46130D3BAB42E00F4DD08155EF286A16167_inline(L_12, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 254));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 255));
		bool L_14;
		L_14 = ControlContext_Exists_mEEB0CCB244CABE9EAD81EBC5E54CB6B50E18FA0F((&V_3), L_13, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 255));
		if (!L_14)
		{
			goto IL_0134;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 256));
		GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* L_15 = ___2_runtimeHandle;
		GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2 L_16 = (*(GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2*)L_15);
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 257));
		Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 L_17;
		L_17 = ControlContext_GetConfiguration_m5EF5175CD07C7E1661F6AC36ECEA52A293DB0249((&V_3), L_16, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 257));
		V_6 = L_17;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 258));
		RuntimeObject* L_18 = V_0;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 259));
		NullCheck(L_18);
		bool L_19;
		L_19 = InterfaceFuncInvoker0< bool >::Invoke(0, ICapabilities_tF49934ED8BF0930F82A0A54F794949FB61194793_il2cpp_TypeInfo_var, L_18);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 259));
		Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 L_20 = V_6;
		bool L_21 = L_20.___IsFinite;
		if ((((int32_t)L_19) == ((int32_t)L_21)))
		{
			goto IL_0092;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 260));
		Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C* L_22 = ___0_generatorObjectDefinition;
		RuntimeObject* L_23 = V_0;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 261));
		NullCheck(L_23);
		bool L_24;
		L_24 = InterfaceFuncInvoker0< bool >::Invoke(0, ICapabilities_tF49934ED8BF0930F82A0A54F794949FB61194793_il2cpp_TypeInfo_var, L_23);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 261));
		bool L_25 = L_24;
		RuntimeObject* L_26 = Box(il2cpp_defaults.boolean_class, &L_25);
		Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060 L_27 = V_6;
		bool L_28 = L_27.___IsFinite;
		bool L_29 = L_28;
		RuntimeObject* L_30 = Box(il2cpp_defaults.boolean_class, &L_29);
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 262));
		String_t* L_31;
		L_31 = String_Format_mA0534D6E2AE4D67A6BD8D45B3321323930EB930C(_stringLiteral5C2C12AF4EFFBF824B747CFFBFC316CAE24077D1, L_22, L_26, L_30, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 262));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 263));
		il2cpp_codegen_runtime_class_init_inline(Debug_t8394C7EEAECA3689C2C9B9DE9C7166D73596276F_il2cpp_TypeInfo_var);
		Debug_LogError_mB00B2B4468EF3CAF041B038D840820FB84C924B2(L_31, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 263));
	}

IL_0092:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 264));
		RuntimeObject* L_32 = V_0;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 265));
		NullCheck(L_32);
		bool L_33;
		L_33 = InterfaceFuncInvoker0< bool >::Invoke(1, ICapabilities_tF49934ED8BF0930F82A0A54F794949FB61194793_il2cpp_TypeInfo_var, L_32);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 265));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 266));
		bool L_34;
		L_34 = Configuration_get_isRealtime_m99E988C200947A8277C144A84CB1755B5A0C2D78_inline((&V_6), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 266));
		if ((((int32_t)L_33) == ((int32_t)L_34)))
		{
			goto IL_00c8;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 267));
		Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C* L_35 = ___0_generatorObjectDefinition;
		RuntimeObject* L_36 = V_0;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 268));
		NullCheck(L_36);
		bool L_37;
		L_37 = InterfaceFuncInvoker0< bool >::Invoke(1, ICapabilities_tF49934ED8BF0930F82A0A54F794949FB61194793_il2cpp_TypeInfo_var, L_36);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 268));
		bool L_38 = L_37;
		RuntimeObject* L_39 = Box(il2cpp_defaults.boolean_class, &L_38);
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 269));
		bool L_40;
		L_40 = Configuration_get_isRealtime_m99E988C200947A8277C144A84CB1755B5A0C2D78_inline((&V_6), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 269));
		bool L_41 = L_40;
		RuntimeObject* L_42 = Box(il2cpp_defaults.boolean_class, &L_41);
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 270));
		String_t* L_43;
		L_43 = String_Format_mA0534D6E2AE4D67A6BD8D45B3321323930EB930C(_stringLiteral0D4DFFEDA70FA6D865B68C20C1F40F10FC31B6DD, L_35, L_39, L_42, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 270));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 271));
		il2cpp_codegen_runtime_class_init_inline(Debug_t8394C7EEAECA3689C2C9B9DE9C7166D73596276F_il2cpp_TypeInfo_var);
		Debug_LogError_mB00B2B4468EF3CAF041B038D840820FB84C924B2(L_43, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 271));
	}

IL_00c8:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 272));
		RuntimeObject* L_44 = V_0;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 273));
		NullCheck(L_44);
		Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 L_45;
		L_45 = InterfaceFuncInvoker0< Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 >::Invoke(2, ICapabilities_tF49934ED8BF0930F82A0A54F794949FB61194793_il2cpp_TypeInfo_var, L_44);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 273));
		V_7 = L_45;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 274));
		Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 L_46;
		L_46 = Configuration_get_length_mB699EC1CF6B8A0955A60B55ABB22AD00A3F6BC3B((&V_6), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 274));
		V_8 = L_46;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 275));
		bool L_47;
		L_47 = Nullable_1_get_HasValue_m2C09C399366A16930BBC996441FE7CED2907D3D0_inline((&V_7), Nullable_1_get_HasValue_m2C09C399366A16930BBC996441FE7CED2907D3D0_RuntimeMethod_var);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 275));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 276));
		bool L_48;
		L_48 = Nullable_1_get_HasValue_m2C09C399366A16930BBC996441FE7CED2907D3D0_inline((&V_8), Nullable_1_get_HasValue_m2C09C399366A16930BBC996441FE7CED2907D3D0_RuntimeMethod_var);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 276));
		if ((((int32_t)L_47) == ((int32_t)L_48)))
		{
			goto IL_00ec;
		}
	}
	{
		G_B11_0 = 1;
		goto IL_010b;
	}

IL_00ec:
	{
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 277));
		bool L_49;
		L_49 = Nullable_1_get_HasValue_m2C09C399366A16930BBC996441FE7CED2907D3D0_inline((&V_7), Nullable_1_get_HasValue_m2C09C399366A16930BBC996441FE7CED2907D3D0_RuntimeMethod_var);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 277));
		if (L_49)
		{
			goto IL_00f8;
		}
	}
	{
		G_B11_0 = 0;
		goto IL_010b;
	}

IL_00f8:
	{
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 278));
		DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E L_50;
		L_50 = Nullable_1_GetValueOrDefault_m5879DF28E8CBC03BD7B2F3A7B383BB0068DE64DC_inline((&V_7), Nullable_1_GetValueOrDefault_m5879DF28E8CBC03BD7B2F3A7B383BB0068DE64DC_RuntimeMethod_var);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 278));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 279));
		DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E L_51;
		L_51 = Nullable_1_GetValueOrDefault_m5879DF28E8CBC03BD7B2F3A7B383BB0068DE64DC_inline((&V_8), Nullable_1_GetValueOrDefault_m5879DF28E8CBC03BD7B2F3A7B383BB0068DE64DC_RuntimeMethod_var);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 279));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 280));
		il2cpp_codegen_runtime_class_init_inline(DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E_il2cpp_TypeInfo_var);
		bool L_52;
		L_52 = DiscreteTime_op_Inequality_m4C12F6A54E5C6E8BAC45A3903E6C2A3127C6063C_inline(L_50, L_51, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 280));
		G_B11_0 = ((int32_t)(L_52));
	}

IL_010b:
	{
		if (!G_B11_0)
		{
			goto IL_0134;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 281));
		Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C* L_53 = ___0_generatorObjectDefinition;
		RuntimeObject* L_54 = V_0;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 282));
		NullCheck(L_54);
		Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 L_55;
		L_55 = InterfaceFuncInvoker0< Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 >::Invoke(2, ICapabilities_tF49934ED8BF0930F82A0A54F794949FB61194793_il2cpp_TypeInfo_var, L_54);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 282));
		Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 L_56 = L_55;
		RuntimeObject* L_57 = Box(Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363_il2cpp_TypeInfo_var, &L_56);
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 283));
		Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 L_58;
		L_58 = Configuration_get_length_mB699EC1CF6B8A0955A60B55ABB22AD00A3F6BC3B((&V_6), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 283));
		Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363 L_59 = L_58;
		RuntimeObject* L_60 = Box(Nullable_1_t9EF99F82DC3D0A8DFF605D72E3793599BE02E363_il2cpp_TypeInfo_var, &L_59);
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 284));
		String_t* L_61;
		L_61 = String_Format_mA0534D6E2AE4D67A6BD8D45B3321323930EB930C(_stringLiteralEE560D196E71D95F90A39910549B06428576F27C, L_53, L_57, L_60, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 284));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 285));
		il2cpp_codegen_runtime_class_init_inline(Debug_t8394C7EEAECA3689C2C9B9DE9C7166D73596276F_il2cpp_TypeInfo_var);
		Debug_LogError_mB00B2B4468EF3CAF041B038D840820FB84C924B2(L_61, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 285));
	}

IL_0134:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 286));
		uintptr_t L_62 = (il2cpp_codegen_conv<uintptr_t,int32_t,int32_t,false,false>(0,NULL));
		V_2 = (ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67*)L_62;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 287));
		return;
	}

IL_0138:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 288));
		GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* L_63 = ___2_runtimeHandle;
		il2cpp_codegen_initobj(L_63, sizeof(GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 289));
		Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C* L_64 = ___0_generatorObjectDefinition;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 290));
		String_t* L_65;
		L_65 = String_Format_mFB7DA489BD99F4670881FF50EC017BFB0A5C0987(_stringLiteralC767BA736F2BEEB0EC1BA27ABE77214EC763C9B6, L_64, _stringLiteral5A10D0C56FEA8FB8816E3E1F6F88D55578F844F7, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 290));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 291));
		il2cpp_codegen_runtime_class_init_inline(Debug_t8394C7EEAECA3689C2C9B9DE9C7166D73596276F_il2cpp_TypeInfo_var);
		Debug_LogError_mB00B2B4468EF3CAF041B038D840820FB84C924B2(L_65, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 291));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 292));
		return;
	}
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool ScriptableProcessorBindings_CheckProcessorExists_mCA17BD1A2B9E776034C7B312CA810B3B739AA04E (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___0_handle, ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* ___1_control, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ScriptableProcessorBindings_CheckProcessorExists_mCA17BD1A2B9E776034C7B312CA810B3B739AA04E_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_handle), (&___1_control));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ScriptableProcessorBindings_CheckProcessorExists_mCA17BD1A2B9E776034C7B312CA810B3B739AA04E_RuntimeMethod_var, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 293));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 294));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 295));
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 L_0 = ___0_handle;
		ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* L_1 = ___1_control;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 296));
		bool L_2;
		L_2 = ScriptableProcessorBindings_CheckProcessorExistsInternal_mF6C33BA9D06B46EAAA47D05E74BA20CC604141A6(L_0, (void*)L_1, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 296));
		return L_2;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool ScriptableProcessorBindings_CheckProcessorExistsInternal_mF6C33BA9D06B46EAAA47D05E74BA20CC604141A6 (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___0_handle, void* ___1_control, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ScriptableProcessorBindings_CheckProcessorExistsInternal_mF6C33BA9D06B46EAAA47D05E74BA20CC604141A6_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ScriptableProcessorBindings_CheckProcessorExistsInternal_mF6C33BA9D06B46EAAA47D05E74BA20CC604141A6_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_PAUSE_POINT;
	{
		void* L_0 = ___1_control;
		bool L_1;
		L_1 = ScriptableProcessorBindings_CheckProcessorExistsInternal_Injected_mD29018C86FF29463FEC0346E4D8308F7F6EA1831((&___0_handle), L_0, NULL);
		return L_1;
	}
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool ScriptableProcessorBindings_CheckProcessorExistsInternal_Injected_mD29018C86FF29463FEC0346E4D8308F7F6EA1831 (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* ___0_handle, void* ___1_control, const RuntimeMethod* method) 
{
	typedef bool (*ScriptableProcessorBindings_CheckProcessorExistsInternal_Injected_mD29018C86FF29463FEC0346E4D8308F7F6EA1831_ftn) (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153*, void*);
	static ScriptableProcessorBindings_CheckProcessorExistsInternal_Injected_mD29018C86FF29463FEC0346E4D8308F7F6EA1831_ftn _il2cpp_icall_func;
	if (!_il2cpp_icall_func)
	_il2cpp_icall_func = (ScriptableProcessorBindings_CheckProcessorExistsInternal_Injected_mD29018C86FF29463FEC0346E4D8308F7F6EA1831_ftn)il2cpp_codegen_resolve_icall ("UnityEngine.Audio.ScriptableProcessorBindings::CheckProcessorExistsInternal_Injected(Unity.Audio.Handle&,System.Void*)");
	bool icallRetVal = _il2cpp_icall_func(___0_handle, ___1_control);
	return icallRetVal;
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR Node_tE9DD997AC2A1CDC0DF9579D3B88467E7F42142C8* Handle_get_AtomicNode_m3D7AF7852BDF5999877F8F973FDF8724974B0A50 (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_get_AtomicNode_m3D7AF7852BDF5999877F8F973FDF8724974B0A50_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Handle_get_AtomicNode_m3D7AF7852BDF5999877F8F973FDF8724974B0A50_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 297));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 298));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 299));
		intptr_t L_0 = __this->___m_Node;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 300));
		void* L_1;
		L_1 = IntPtr_op_Explicit_m2728CBA081E79B97DDCF1D4FAD77B309CA1E94BF(L_0, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 300));
		return (Node_tE9DD997AC2A1CDC0DF9579D3B88467E7F42142C8*)(L_1);
	}
}
IL2CPP_EXTERN_C  Node_tE9DD997AC2A1CDC0DF9579D3B88467E7F42142C8* Handle_get_AtomicNode_m3D7AF7852BDF5999877F8F973FDF8724974B0A50_AdjustorThunk (RuntimeObject* __this, const RuntimeMethod* method)
{
	Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153>(__this);
	Node_tE9DD997AC2A1CDC0DF9579D3B88467E7F42142C8* _returnValue;
	_returnValue = Handle_get_AtomicNode_m3D7AF7852BDF5999877F8F973FDF8724974B0A50(_thisAdjusted, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool Handle_Equals_m5D8356E5FCA91FFFEACC910C738C37690EBA2E64 (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* __this, Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___0_other, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_Equals_m5D8356E5FCA91FFFEACC910C738C37690EBA2E64_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_other));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Handle_Equals_m5D8356E5FCA91FFFEACC910C738C37690EBA2E64_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 301));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 302));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 303));
		intptr_t L_0 = __this->___m_Node;
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 L_1 = ___0_other;
		intptr_t L_2 = L_1.___m_Node;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 304));
		bool L_3;
		L_3 = IntPtr_op_Equality_m7D9CDCDE9DC2A0C2C614633F4921E90187FAB271_inline(L_0, L_2, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 304));
		if (!L_3)
		{
			goto IL_0022;
		}
	}
	{
		int32_t L_4 = __this->___Version;
		Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 L_5 = ___0_other;
		int32_t L_6 = L_5.___Version;
		return (bool)((((int32_t)L_4) == ((int32_t)L_6))? 1 : 0);
	}

IL_0022:
	{
		return (bool)0;
	}
}
IL2CPP_EXTERN_C  bool Handle_Equals_m5D8356E5FCA91FFFEACC910C738C37690EBA2E64_AdjustorThunk (RuntimeObject* __this, Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153 ___0_other, const RuntimeMethod* method)
{
	Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153>(__this);
	bool _returnValue;
	_returnValue = Handle_Equals_m5D8356E5FCA91FFFEACC910C738C37690EBA2E64(_thisAdjusted, ___0_other, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool Handle_Equals_mDE217E745B1016A74BCE82848675ED913B391B8F (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* __this, RuntimeObject* ___0_obj, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_Equals_mDE217E745B1016A74BCE82848675ED913B391B8F_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153_0_0_0_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_obj));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Handle_Equals_mDE217E745B1016A74BCE82848675ED913B391B8F_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 305));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 306));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 307));
		RuntimeObject* L_0 = ___0_obj;
		if (L_0)
		{
			goto IL_0005;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 308));
		return (bool)0;
	}

IL_0005:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 309));
		RuntimeObject* L_1 = ___0_obj;
		if (!((RuntimeObject*)IsInstSealed((RuntimeObject*)L_1, Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153_il2cpp_TypeInfo_var)))
		{
			goto IL_001a;
		}
	}
	{
		RuntimeObject* L_2 = ___0_obj;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 310));
		bool L_3;
		L_3 = Handle_Equals_m5D8356E5FCA91FFFEACC910C738C37690EBA2E64(__this, ((*(Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153*)UnBox(L_2, Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153_il2cpp_TypeInfo_var))), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 310));
		return L_3;
	}

IL_001a:
	{
		return (bool)0;
	}
}
IL2CPP_EXTERN_C  bool Handle_Equals_mDE217E745B1016A74BCE82848675ED913B391B8F_AdjustorThunk (RuntimeObject* __this, RuntimeObject* ___0_obj, const RuntimeMethod* method)
{
	Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153>(__this);
	bool _returnValue;
	_returnValue = Handle_Equals_mDE217E745B1016A74BCE82848675ED913B391B8F(_thisAdjusted, ___0_obj, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR int32_t Handle_GetHashCode_m8DD5E2EE5197C1FF37CD2CF3B4FD892A9E299DFE (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_GetHashCode_m8DD5E2EE5197C1FF37CD2CF3B4FD892A9E299DFE_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Handle_GetHashCode_m8DD5E2EE5197C1FF37CD2CF3B4FD892A9E299DFE_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 311));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 312));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 313));
		intptr_t L_0 = __this->___m_Node;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 314));
		int32_t L_1;
		L_1 = IntPtr_op_Explicit_mC33775570B5AC86421DABA8F8B9885DBFF49B02F(L_0, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 314));
		int32_t L_2 = __this->___Version;
		return ((int32_t)(((int32_t)il2cpp_codegen_multiply(L_1, ((int32_t)397)))^L_2));
	}
}
IL2CPP_EXTERN_C  int32_t Handle_GetHashCode_m8DD5E2EE5197C1FF37CD2CF3B4FD892A9E299DFE_AdjustorThunk (RuntimeObject* __this, const RuntimeMethod* method)
{
	Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153>(__this);
	int32_t _returnValue;
	_returnValue = Handle_GetHashCode_m8DD5E2EE5197C1FF37CD2CF3B4FD892A9E299DFE(_thisAdjusted, method);
	return _returnValue;
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR void Handle_CheckValidOrThrow_mA6C3BAA711CDA462A6A2653A1A2D04CE2AECD3C3 (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_CheckValidOrThrow_mA6C3BAA711CDA462A6A2653A1A2D04CE2AECD3C3_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Handle_CheckValidOrThrow_mA6C3BAA711CDA462A6A2653A1A2D04CE2AECD3C3_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 315));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 316));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 317));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 318));
		bool L_0;
		L_0 = Handle_get_ValidAndNotDisposed_m1097F1E099632EDF74478AD5B74978BD3FAEF145(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 318));
		if (L_0)
		{
			goto IL_0013;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 319));
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 320));
		InvalidOperationException_t5DDE4D49B7405FAAB1E4576F4715A42A3FAD4BAB* L_1 = (InvalidOperationException_t5DDE4D49B7405FAAB1E4576F4715A42A3FAD4BAB*)il2cpp_codegen_object_new(((RuntimeClass*)il2cpp_codegen_initialize_runtime_metadata_inline((uintptr_t*)&InvalidOperationException_t5DDE4D49B7405FAAB1E4576F4715A42A3FAD4BAB_il2cpp_TypeInfo_var)));
		InvalidOperationException__ctor_mE4CB6F4712AB6D99A2358FBAE2E052B3EE976162(L_1, ((String_t*)il2cpp_codegen_initialize_runtime_metadata_inline((uintptr_t*)&_stringLiteral23ABA34B45DF51C7D9C0E116AA6FDA4749E8C618)), NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 320));
		IL2CPP_RAISE_MANAGED_EXCEPTION(L_1, ((RuntimeMethod*)il2cpp_codegen_initialize_runtime_metadata_inline((uintptr_t*)&Handle_CheckValidOrThrow_mA6C3BAA711CDA462A6A2653A1A2D04CE2AECD3C3_RuntimeMethod_var)));
	}

IL_0013:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 321));
		return;
	}
}
IL2CPP_EXTERN_C  void Handle_CheckValidOrThrow_mA6C3BAA711CDA462A6A2653A1A2D04CE2AECD3C3_AdjustorThunk (RuntimeObject* __this, const RuntimeMethod* method)
{
	Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153>(__this);
	Handle_CheckValidOrThrow_mA6C3BAA711CDA462A6A2653A1A2D04CE2AECD3C3(_thisAdjusted, method);
}
IL2CPP_EXTERN_C IL2CPP_METHOD_ATTR bool Handle_get_ValidAndNotDisposed_m1097F1E099632EDF74478AD5B74978BD3FAEF145 (Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_get_ValidAndNotDisposed_m1097F1E099632EDF74478AD5B74978BD3FAEF145_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Handle_get_ValidAndNotDisposed_m1097F1E099632EDF74478AD5B74978BD3FAEF145_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 322));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 323));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 324));
		intptr_t L_0 = __this->___m_Node;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 325));
		bool L_1;
		L_1 = IntPtr_op_Inequality_m90EFC9C4CAD9A33E309F2DDF98EE4E1DD253637B_inline(L_0, 0, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 325));
		if (!L_1)
		{
			goto IL_0034;
		}
	}
	{
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 326));
		Node_tE9DD997AC2A1CDC0DF9579D3B88467E7F42142C8* L_2;
		L_2 = Handle_get_AtomicNode_m3D7AF7852BDF5999877F8F973FDF8724974B0A50(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 326));
		NullCheck(L_2);
		int32_t L_3 = L_2->___Version;
		int32_t L_4 = __this->___Version;
		if ((!(((uint32_t)L_3) == ((uint32_t)L_4))))
		{
			goto IL_0034;
		}
	}
	{
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 327));
		Node_tE9DD997AC2A1CDC0DF9579D3B88467E7F42142C8* L_5;
		L_5 = Handle_get_AtomicNode_m3D7AF7852BDF5999877F8F973FDF8724974B0A50(__this, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 327));
		NullCheck(L_5);
		int32_t L_6 = L_5->___AllocationFlags;
		return (bool)((((int32_t)L_6) == ((int32_t)0))? 1 : 0);
	}

IL_0034:
	{
		return (bool)0;
	}
}
IL2CPP_EXTERN_C  bool Handle_get_ValidAndNotDisposed_m1097F1E099632EDF74478AD5B74978BD3FAEF145_AdjustorThunk (RuntimeObject* __this, const RuntimeMethod* method)
{
	Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153* _thisAdjusted;
	_thisAdjusted = il2cpp_codegen_get_raw_data<Handle_t5E550C52101EDD3CC66477987E73F87CCCFD5153>(__this);
	bool _returnValue;
	_returnValue = Handle_get_ValidAndNotDisposed_m1097F1E099632EDF74478AD5B74978BD3FAEF145(_thisAdjusted, method);
	return _returnValue;
}
#ifdef __clang__
#pragma clang diagnostic pop
#endif
#ifdef __clang__
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Winvalid-offsetof"
#pragma clang diagnostic ignored "-Wunused-variable"
#endif
#ifdef __clang__
#pragma clang diagnostic pop
#endif
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void AudioConfigurationChangeHandler_Invoke_m4DC27DD11512481B60071B20284E6886DAE54DE2_inline (AudioConfigurationChangeHandler_tE071B0CBA3B3A77D3E41F5FCB65B4017885B3177* __this, bool ___0_deviceWasChanged, const RuntimeMethod* method) 
{
	typedef void (*FunctionPointerType) (RuntimeObject*, bool, const RuntimeMethod*);
	((FunctionPointerType)__this->___invoke_impl)((Il2CppObject*)__this->___method_code, ___0_deviceWasChanged, reinterpret_cast<RuntimeMethod*>(__this->___method));
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void Action_Invoke_m7126A54DACA72B845424072887B5F3A51FC3808E_inline (Action_tD00B0A84D7945E50C2DFFC28EFEE6ED44ED2AD07* __this, const RuntimeMethod* method) 
{
	typedef void (*FunctionPointerType) (RuntimeObject*, const RuntimeMethod*);
	((FunctionPointerType)__this->___invoke_impl)((Il2CppObject*)__this->___method_code, reinterpret_cast<RuntimeMethod*>(__this->___method));
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool Mobile_get_muteState_m64C1E8C61537317A7F153E1A72F7D39D85DA684D_inline (const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_get_muteState_m64C1E8C61537317A7F153E1A72F7D39D85DA684D_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Mobile_get_muteState_m64C1E8C61537317A7F153E1A72F7D39D85DA684D_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 14));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 15));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 16));
		bool L_0 = ((Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_StaticFields*)il2cpp_codegen_static_fields_for(Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var))->___U3CmuteStateU3Ek__BackingField;
		return L_0;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void Mobile_set_muteState_m7C9A464BCA3762330E18CCAD79AF6C47B863CA02_inline (bool ___0_value, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_set_muteState_m7C9A464BCA3762330E18CCAD79AF6C47B863CA02_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_value));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Mobile_set_muteState_m7C9A464BCA3762330E18CCAD79AF6C47B863CA02_RuntimeMethod_var, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 17));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 18));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 19));
		bool L_0 = ___0_value;
		((Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_StaticFields*)il2cpp_codegen_static_fields_for(Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var))->___U3CmuteStateU3Ek__BackingField = L_0;
		return;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool Mobile_get_stopAudioOutputOnMute_m43EC82258D38C418353DFE19F32B51B64B18DCCA_inline (const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_get_stopAudioOutputOnMute_m43EC82258D38C418353DFE19F32B51B64B18DCCA_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Mobile_get_stopAudioOutputOnMute_m43EC82258D38C418353DFE19F32B51B64B18DCCA_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 20));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 21));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 22));
		bool L_0 = ((Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_StaticFields*)il2cpp_codegen_static_fields_for(Mobile_t304A73480DF447472BDB16BA19A9E4FE2C8CB2DD_il2cpp_TypeInfo_var))->____stopAudioOutputOnMute;
		return L_0;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void PCMReaderCallback_Invoke_m76784C690C36B513E2AA5B0E4FD9831B2C7E5152_inline (PCMReaderCallback_t3396D9613664F0AFF65FB91018FD0F901CC16F1E* __this, SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C* ___0_data, const RuntimeMethod* method) 
{
	typedef void (*FunctionPointerType) (RuntimeObject*, SingleU5BU5D_t89DEFE97BCEDB5857010E79ECE0F52CF6E93B87C*, const RuntimeMethod*);
	((FunctionPointerType)__this->___invoke_impl)((Il2CppObject*)__this->___method_code, ___0_data, reinterpret_cast<RuntimeMethod*>(__this->___method));
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void PCMSetPositionCallback_Invoke_m434D4F02FA25F91DF6199EC5A799C551C7F93702_inline (PCMSetPositionCallback_t8D7135A2FB40647CAEC93F5254AD59E18DEB6072* __this, int32_t ___0_position, const RuntimeMethod* method) 
{
	typedef void (*FunctionPointerType) (RuntimeObject*, int32_t, const RuntimeMethod*);
	((FunctionPointerType)__this->___invoke_impl)((Il2CppObject*)__this->___method_code, ___0_position, reinterpret_cast<RuntimeMethod*>(__this->___method));
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E DiscreteTime_FromTicks_m0AF37F302A6729B9C86ACBBBF3CA26471DF131BC_inline (int64_t ___0_v, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&DiscreteTime_FromTicks_m0AF37F302A6729B9C86ACBBBF3CA26471DF131BC_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_v));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, DiscreteTime_FromTicks_m0AF37F302A6729B9C86ACBBBF3CA26471DF131BC_RuntimeMethod_var, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 230));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 231));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 232));
		int64_t L_0 = ___0_v;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 233));
		DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E L_1;
		memset((&L_1), 0, sizeof(L_1));
		DiscreteTime__ctor_m5DF0E73E12BD613EE452B88012E01EF83E70383E_inline((&L_1), L_0, 0, NULL);
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 233));
		return L_1;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D AudioFormat_get_audioConfiguration_m769CBA67D62C1D12FBE6C55DC2429D62BA135D43_inline (AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioFormat_get_audioConfiguration_m769CBA67D62C1D12FBE6C55DC2429D62BA135D43_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioFormat_tC9651BFD36B41D1FC782C702B6C980D9768F699D_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioFormat_get_audioConfiguration_m769CBA67D62C1D12FBE6C55DC2429D62BA135D43_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 147));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 148));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 149));
		AudioConfiguration_t4C8585EA98B6559B306B6FAD6A68088555394A5D L_0 = __this->___m_Config;
		return L_0;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* ControlContext_get_Header_m48ED40585DBA374B2750157BEFD1A0DC92B654E2_inline (ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlContext_get_Header_m48ED40585DBA374B2750157BEFD1A0DC92B654E2_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&ControlContext_t67F00D3C59C26C77BED313684AB258AEC5C5A243_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, ControlContext_get_Header_m48ED40585DBA374B2750157BEFD1A0DC92B654E2_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 150));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 151));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 152));
		ControlHeader_t88FD879CA9C5610D6410BA56087244CEA5DE5A67* L_0 = __this->___m_Header;
		return L_0;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void SampleFramesHandler_Invoke_m478D5645634B8C734E58B59CF7750797FC54F1BC_inline (SampleFramesHandler_tFE84FF9BBCEFB880D46227188F375BEF680AAA30* __this, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2* ___0_provider, uint32_t ___1_sampleFrameCount, const RuntimeMethod* method) 
{
	typedef void (*FunctionPointerType) (RuntimeObject*, AudioSampleProvider_t602353124A2F6F2AEC38E56C3C21932344F712E2*, uint32_t, const RuntimeMethod*);
	((FunctionPointerType)__this->___invoke_impl)((Il2CppObject*)__this->___method_code, ___0_provider, ___1_sampleFrameCount, reinterpret_cast<RuntimeMethod*>(__this->___method));
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 AudioClipPlayable_GetHandle_mEA1D664328FF9B08E4F7D5EBCD4B51A754D97C44_inline (AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClipPlayable_GetHandle_mEA1D664328FF9B08E4F7D5EBCD4B51A754D97C44_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioClipPlayable_tD4B758E68CAE03CB0CD31F90C8A3E603B97143A0_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioClipPlayable_GetHandle_mEA1D664328FF9B08E4F7D5EBCD4B51A754D97C44_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 129));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 130));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 131));
		PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 L_0 = __this->___m_Handle;
		return L_0;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 AudioMixerPlayable_GetHandle_m6C182D9794E901D123223BB57738A302BEAB41FD_inline (AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioMixerPlayable_GetHandle_m6C182D9794E901D123223BB57738A302BEAB41FD_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&AudioMixerPlayable_t6AADDF0C53DF1B4C17969EC24B3B4E4975F3A56C_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, AudioMixerPlayable_GetHandle_m6C182D9794E901D123223BB57738A302BEAB41FD_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 138));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 139));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 140));
		PlayableHandle_t5D6A01EF94382EFEDC047202F71DF882769654D4 L_0 = __this->___m_Handle;
		return L_0;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool IntPtr_op_Inequality_m90EFC9C4CAD9A33E309F2DDF98EE4E1DD253637B_inline (intptr_t ___0_value1, intptr_t ___1_value2, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&IntPtr_op_Inequality_m90EFC9C4CAD9A33E309F2DDF98EE4E1DD253637B_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, IntPtr_op_Inequality_m90EFC9C4CAD9A33E309F2DDF98EE4E1DD253637B_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_PAUSE_POINT;
	{
		intptr_t L_0 = ___0_value1;
		intptr_t L_1 = ___1_value2;
		return (bool)((((int32_t)((((intptr_t)L_0) == ((intptr_t)L_1))? 1 : 0)) == ((int32_t)0))? 1 : 0);
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool GCHandle_get_IsAllocated_m241908103D8D867E11CCAB73C918729825E86843_inline (GCHandle_tC44F6F72EE68BD4CFABA24309DA7A179D41127DC* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GCHandle_get_IsAllocated_m241908103D8D867E11CCAB73C918729825E86843_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, GCHandle_get_IsAllocated_m241908103D8D867E11CCAB73C918729825E86843_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_PAUSE_POINT;
	{
		intptr_t L_0 = __this->___handle;
		bool L_1;
		L_1 = IntPtr_op_Inequality_m90EFC9C4CAD9A33E309F2DDF98EE4E1DD253637B_inline(L_0, 0, NULL);
		return L_1;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool Configuration_get_isRealtime_m99E988C200947A8277C144A84CB1755B5A0C2D78_inline (Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060* __this, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Configuration_get_isRealtime_m99E988C200947A8277C144A84CB1755B5A0C2D78_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&Configuration_t6237CF0DD0C43C64808F31B712BA308606D3F060_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, Configuration_get_isRealtime_m99E988C200947A8277C144A84CB1755B5A0C2D78_RuntimeMethod_var, methodExecutionContextThis, NULL, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 206));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 207));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 208));
		bool L_0 = __this->___IsRealtime;
		return L_0;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 GeneratorInstance_op_Implicit_mB7A6E46130D3BAB42E00F4DD08155EF286A16167_inline (GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* ___0_generatorInstance, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&GeneratorInstance_op_Implicit_mB7A6E46130D3BAB42E00F4DD08155EF286A16167_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_generatorInstance));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, GeneratorInstance_op_Implicit_mB7A6E46130D3BAB42E00F4DD08155EF286A16167_RuntimeMethod_var, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 185));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 186));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_AudioModule + 187));
		GeneratorInstance_t2721F6826DF0F07285CF2F765C273DFD4D8201C2* L_0 = ___0_generatorInstance;
		ProcessorInstance_tC8E3131DB14380822C20BA430BC6BFB4BE0F8B35 L_1 = L_0->___m_ProcessorInstance;
		return L_1;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool DiscreteTime_op_Inequality_m4C12F6A54E5C6E8BAC45A3903E6C2A3127C6063C_inline (DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E ___0_lhs, DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E ___1_rhs, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&DiscreteTime_op_Inequality_m4C12F6A54E5C6E8BAC45A3903E6C2A3127C6063C_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_lhs), (&___1_rhs));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, DiscreteTime_op_Inequality_m4C12F6A54E5C6E8BAC45A3903E6C2A3127C6063C_RuntimeMethod_var, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 240));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 241));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 242));
		DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E L_0 = ___0_lhs;
		int64_t L_1 = L_0.___Value;
		DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E L_2 = ___1_rhs;
		int64_t L_3 = L_2.___Value;
		return (bool)((((int32_t)((((int64_t)L_1) == ((int64_t)L_3))? 1 : 0)) == ((int32_t)0))? 1 : 0);
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool IntPtr_op_Equality_m7D9CDCDE9DC2A0C2C614633F4921E90187FAB271_inline (intptr_t ___0_value1, intptr_t ___1_value2, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&IntPtr_op_Equality_m7D9CDCDE9DC2A0C2C614633F4921E90187FAB271_RuntimeMethod_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, IntPtr_op_Equality_m7D9CDCDE9DC2A0C2C614633F4921E90187FAB271_RuntimeMethod_var, NULL, NULL, NULL);
	CHECK_PAUSE_POINT;
	{
		intptr_t L_0 = ___0_value1;
		intptr_t L_1 = ___1_value2;
		return (bool)((((intptr_t)L_0) == ((intptr_t)L_1))? 1 : 0);
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void Action_1_Invoke_m5A038831CEB84A7E374FE59D43444412629F833F_gshared_inline (Action_1_t923A20D1D4F6B55B2ED5AE21B90F1A0CE0450D99* __this, Il2CppFullySharedGenericAny ___0_obj, const RuntimeMethod* method) 
{
	typedef void (*FunctionPointerType) (RuntimeObject*, Il2CppFullySharedGenericAny, const RuntimeMethod*);
	((FunctionPointerType)__this->___invoke_impl)((Il2CppObject*)__this->___method_code, ___0_obj, reinterpret_cast<RuntimeMethod*>(__this->___method));
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR intptr_t MarshalledUnityObject_MarshalNotNull_TisIl2CppSharedGenericObject_mCE897EC9A79983B4B1E6E2C8342452256309044A_gshared_inline (Il2CppSharedGenericObject* ___0_obj, const RuntimeMethod* method) 
{
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_obj));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, method, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 9317));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 9318));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 9319));
		Il2CppSharedGenericObject* L_0 = ___0_obj;
		NullCheck(L_0);
		intptr_t L_1 = ((Object_tC12DECB6760A7F2CBF65D9DCF18D044C2D97152C*)L_0)->___m_CachedPtr;
		return L_1;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR bool Nullable_1_get_HasValue_m14F273FB376DF00D727434CDCD28AB4EDCC14C3C_gshared_inline (Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339* __this, const RuntimeMethod* method) 
{
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, method, NULL, NULL, NULL);
	CHECK_PAUSE_POINT;
	{
		bool L_0 = *(bool*)il2cpp_codegen_get_instance_field_data_pointer(__this, il2cpp_rgctx_field(il2cpp_rgctx_data_no_init(InitializedTypeInfo(method->klass)->rgctx_data, 1),0));
		return L_0;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR intptr_t MarshalledUnityObject_Marshal_TisIl2CppSharedGenericObject_m35CB06885EF5600EDBB840B54EDAF3A806896DBB_gshared_inline (Il2CppSharedGenericObject* ___0_obj, const RuntimeMethod* method) 
{
	il2cpp_rgctx_method_init(method);
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_obj));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, method, NULL, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 9311));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 9312));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 9313));
		Il2CppSharedGenericObject* L_0 = ___0_obj;
		if (L_0)
		{
			goto IL_000e;
		}
	}
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 9314));
		return 0;
	}

IL_000e:
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 9315));
		Il2CppSharedGenericObject* L_1 = ___0_obj;
		STORE_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 9316));
		intptr_t L_2;
		L_2 = MarshalledUnityObject_MarshalNotNull_TisIl2CppSharedGenericObject_mCE897EC9A79983B4B1E6E2C8342452256309044A_inline(L_1, il2cpp_rgctx_method(method->rgctx_data, 1));
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 9316));
		return L_2;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void Nullable_1_GetValueOrDefault_mC057FBD944AF068B90EBDD0B496231A01B2A4228_gshared_inline (Nullable_1_t71C4EA4E848DBD7A4A97704069FB951159A3A339* __this, Il2CppFullySharedGenericStruct* il2cppRetVal, const RuntimeMethod* method) 
{
	const uint32_t SizeOf_T_tF1352992D99D495C6F2BE3DC43F8A00BAD6B2EAA = il2cpp_codegen_sizeof(il2cpp_rgctx_data_no_init(InitializedTypeInfo(method->klass)->rgctx_data, 0));
	const Il2CppFullySharedGenericStruct L_0 = alloca(SizeOf_T_tF1352992D99D495C6F2BE3DC43F8A00BAD6B2EAA);
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, method, NULL, NULL, NULL);
	CHECK_PAUSE_POINT;
	{
		il2cpp_codegen_memcpy(L_0, il2cpp_codegen_get_instance_field_data_pointer(__this, il2cpp_rgctx_field(il2cpp_rgctx_data_no_init(InitializedTypeInfo(method->klass)->rgctx_data, 1),1)), SizeOf_T_tF1352992D99D495C6F2BE3DC43F8A00BAD6B2EAA);
		il2cpp_codegen_memcpy(il2cppRetVal, L_0, SizeOf_T_tF1352992D99D495C6F2BE3DC43F8A00BAD6B2EAA);
		return;
	}
}
IL2CPP_MANAGED_FORCE_INLINE IL2CPP_METHOD_ATTR void DiscreteTime__ctor_m5DF0E73E12BD613EE452B88012E01EF83E70383E_inline (DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E* __this, int64_t ___0_v, int32_t ___1__, const RuntimeMethod* method) 
{
	static bool s_Il2CppMethodInitialized;
	if (!s_Il2CppMethodInitialized)
	{
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&DiscreteTime__ctor_m5DF0E73E12BD613EE452B88012E01EF83E70383E_RuntimeMethod_var);
		il2cpp_codegen_initialize_runtime_metadata((uintptr_t*)&DiscreteTime_t0954C3B93A9A500A04D33E309649C1CD2780C41E_0_0_0_var);
		s_Il2CppMethodInitialized = true;
	}
	DECLARE_METHOD_THIS(methodExecutionContextThis, (&__this));
	DECLARE_METHOD_PARAMS(methodExecutionContextParameters, (&___0_v), (&___1__));
	DECLARE_METHOD_EXEC_CTX(methodExecutionContext, DiscreteTime__ctor_m5DF0E73E12BD613EE452B88012E01EF83E70383E_RuntimeMethod_var, methodExecutionContextThis, methodExecutionContextParameters, NULL);
	CHECK_METHOD_ENTRY_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 226));
	CHECK_METHOD_EXIT_SEQ_POINT(methodExitChecker, methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 227));
	{
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 228));
		int64_t L_0 = ___0_v;
		__this->___Value = L_0;
		CHECK_SEQ_POINT(methodExecutionContext, (g_sequencePointsUnityEngine_CoreModule + 229));
		return;
	}
}
