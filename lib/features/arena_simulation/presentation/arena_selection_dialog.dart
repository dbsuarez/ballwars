import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../arenas/domain/arena_definition.dart';
import '../../arenas/domain/arena_geometry.dart';
import '../../settings/domain/app_settings.dart';
import '../../settings/presentation/app_settings_scope.dart';
import 'arena_preview.dart';

Future<ArenaDecoration?> showArenaSelectionDialog(BuildContext context, {
  required ArenaDecoration selected,String? selectedPresetId,
  ArenaShape shape=ArenaShape.circle,ValueChanged<ArenaDefinition>? onSelectPreset,
  List<ArenaDefinition> transientPresets = const [],
})=>showDialog<ArenaDecoration>(context:context,builder:(_)=>ArenaSelectionDialog(
  selected:selected,selectedPresetId:selectedPresetId,shape:shape,onSelectPreset:onSelectPreset,
  presets:onSelectPreset==null ? const [] : <String,ArenaDefinition>{
    for (final arena in AppSettingsScope.of(context).arenaCatalog.arenas)
      if (arena.enabled) arena.id:arena,
    for (final arena in transientPresets) arena.id:arena,
  }.values.toList()));

/// Shared by player setup, administrator defaults and Power-up Test.
class ArenaSelectionDialog extends StatelessWidget {
  const ArenaSelectionDialog({super.key,required this.selected,this.selectedPresetId,
    this.shape=ArenaShape.circle,this.presets=const [],this.onSelectPreset});
  final ArenaDecoration selected;
  final String? selectedPresetId;
  final ArenaShape shape;
  final List<ArenaDefinition> presets;
  final ValueChanged<ArenaDefinition>? onSelectPreset;

  Widget grid(BuildContext context, bool custom) => LayoutBuilder(builder:(context,bounds)=>GridView.builder(
    gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:bounds.maxWidth>=260?2:1,
      mainAxisExtent:144*MediaQuery.textScalerOf(context).scale(1).clamp(1,1.5),mainAxisSpacing:10,crossAxisSpacing:10),
    itemCount:custom?presets.length:ArenaDecoration.values.length,itemBuilder:(context,index){
      final preset=custom?presets[index]:null;
      final arena=preset?.trapTheme ?? ArenaDecoration.values[index];
      final name=preset?.name ?? arena.label;
      final caption=preset?.trapCaption ?? arena.hazardCaption;
      final active=preset!=null ? preset.id==selectedPresetId : (selectedPresetId==null || selectedPresetId!.isEmpty) && arena==selected;
      final colors=Theme.of(context).colorScheme;
      return Semantics(selected:active,button:true,label:'$name, $caption',child:Material(
        color:active?colors.primaryContainer:colors.surfaceContainerHighest,
        shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),side:BorderSide(color:active?colors.primary:colors.outlineVariant,width:active?2:1)),
        clipBehavior:Clip.antiAlias,child:InkWell(key:ValueKey(preset==null?'arena-option-${arena.name}':'arena-option-${preset.id}'),
          onTap:(){if(preset!=null)onSelectPreset?.call(preset);Navigator.pop(context,arena);},
          child:Padding(padding:const EdgeInsets.all(8),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Expanded(child:Stack(alignment:Alignment.center,children:[FittedBox(child:ArenaPreview(decoration:arena,arena:preset,shape:shape,size:80)),
              if(active)Positioned(right:0,top:0,child:Icon(Icons.check_circle,color:colors.onPrimaryContainer,size:22))])),
            const SizedBox(height:6),Text(name,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(fontWeight:FontWeight.w700,color:active?colors.onPrimaryContainer:colors.onSurface)),
            const SizedBox(height:3),Text(caption,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:11,color:active?colors.onPrimaryContainer:colors.onSurfaceVariant)),
          ])))));
    }));
  @override
  Widget build(BuildContext context)=>DefaultTabController(length:presets.isEmpty?1:2,
    initialIndex:presets.isNotEmpty && (selectedPresetId??'').isNotEmpty?1:0,
    child:AlertDialog(key:const ValueKey('arena-selection-dialog'),constraints:const BoxConstraints(maxWidth:440),
      insetPadding:const EdgeInsets.symmetric(vertical:24),title:const Text('Choose arena'),
      content:SizedBox(width:400,height:math.min(460,MediaQuery.sizeOf(context).height*.57),child:Column(children:[
        if((selectedPresetId??'').isNotEmpty && !presets.any((a)=>a.id==selectedPresetId))
          const Padding(padding:EdgeInsets.only(bottom:8),child:Text('The selected arena is unavailable. Choose another.')),
        if(presets.isNotEmpty)const TabBar(tabs:[Tab(text:'Built-in'),Tab(text:'Custom')]),
        Expanded(child:presets.isEmpty?grid(context,false):TabBarView(children:[grid(context,false),grid(context,true)])),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel'))]));
}
