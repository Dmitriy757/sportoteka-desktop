import '../controller/events_detail_controller.dart';
import '../models/eventsdetail_item_model.dart';
import 'package:flutter/material.dart';
import 'package:sportoteka/core/app_export.dart';

// ignore: must_be_immutable
class EventsdetailItemWidget extends StatelessWidget {
  EventsdetailItemWidget(
    this.eventsdetailItemModelObj,
    this.index, {
    Key? key,
    this.onTap,
  }) : super(
          key: key,
        );

  EventsdetailItemModel eventsdetailItemModelObj;
  int index;
  final Function(EventsdetailItemModel, int)? onTap;

  EventsDetailController controller = Get.put(EventsDetailController());
  var eventsDetailController = Get.find<EventsDetailController>();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap!(eventsdetailItemModelObj, index);
        } else {
          _showEventDialog(context);
        }
      },
      child: Stack(
        children: [
          CustomImageView(
            imagePath: eventsdetailItemModelObj.image,
            height: double.infinity,
            width: double.infinity,
            radius: BorderRadius.only(
              topLeft: Radius.circular(index == 3 ? 0 : 16.h),
              topRight: Radius.circular(index == 2 ? 0 : 16.h),
              bottomLeft: Radius.circular(index == 1 ? 0 : 16.h),
              bottomRight: Radius.circular(index == 0 ? 0 : 16.h),
            ),
          ),
          if (index == 3)
            Container(
              height: double.infinity,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.60),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(index == 3 ? 0 : 16.h),
                  topRight: Radius.circular(index == 2 ? 0 : 16.h),
                  bottomLeft: Radius.circular(index == 1 ? 0 : 16.h),
                  bottomRight: Radius.circular(index == 0 ? 0 : 16.h),
                ),
              ),
              child: Center(
                child: Text(
                  "+${eventsDetailController.previouseMemory.length - 4} Posts",
                  style: TextStyle(
                    color: appTheme.whiteA700,
                    fontSize: 20.fSize,
                  ),
                ),
              ),
            )
          else
            const SizedBox(),
          
          if (index != 3)
            Positioned(
              top: 8.h,
              right: 8.h,
              child: Container(
                padding: EdgeInsets.all(4.h),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_available_rounded,
                  size: 14.h,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showEventDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: appTheme.whiteA700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.h),
        ),
        title: Row(
          children: [
            Icon(
              Icons.event_available_rounded,
              color: Colors.blue[800], // Используем стандартный цвет
            ),
            SizedBox(width: 8.h),
            Text(
              'Мероприятие',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.fSize,
                color: Colors.blue[800], // Используем стандартный цвет
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eventsdetailItemModelObj.image != null)
              Container(
                height: 120.v,
                width: double.infinity,
                margin: EdgeInsets.only(bottom: 12.v),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.h),
                  image: DecorationImage(
                    image: NetworkImage(eventsdetailItemModelObj.image!),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            
            Text(
              'Подробная информация о мероприятии',
              style: TextStyle(
                fontSize: 14.fSize,
                color: Colors.grey[800], // Используем стандартный цвет
                height: 1.5,
              ),
            ),
            
            SizedBox(height: 16.v),
            
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _showCalendarDialog(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800], // Используем стандартный цвет
                foregroundColor: appTheme.whiteA700,
                minimumSize: Size(double.infinity, 40.v),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.h),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_rounded, size: 18.h),
                  SizedBox(width: 8.h),
                  Text('Открыть календарь'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Закрыть',
              style: TextStyle(color: Colors.grey[800]), // Используем стандартный цвет
            ),
          ),
        ],
      ),
    );
  }

  void _showCalendarDialog(BuildContext context) {
    final now = DateTime.now();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.calendar_today_rounded, color: Colors.blue[800]), // Используем стандартный цвет
            SizedBox(width: 8.h),
            Text('Календарь мероприятий'),
          ],
        ),
        content: Container(
          width: double.maxFinite,
          child: _buildSimpleCalendar(now),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Назад'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessMessage();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800], // Используем стандартный цвет
              foregroundColor: appTheme.whiteA700,
            ),
            child: Text('Добавить в календарь'),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleCalendar(DateTime currentMonth) {
    final firstDay = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDay = DateTime(currentMonth.year, currentMonth.month + 1, 0);
    
    List<Widget> dayWidgets = [];
    List<String> weekDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    
    for (var day in weekDays) {
      dayWidgets.add(
        Container(
          alignment: Alignment.center,
          child: Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12.fSize,
              color: Colors.blue[800], // Используем стандартный цвет
            ),
          ),
        ),
      );
    }
    
    int startWeekday = firstDay.weekday - 1;
    for (int i = 0; i < startWeekday; i++) {
      dayWidgets.add(Container());
    }
    
    for (int day = 1; day <= lastDay.day; day++) {
      final currentDay = DateTime(currentMonth.year, currentMonth.month, day);
      final isToday = currentDay.day == DateTime.now().day && 
                      currentDay.month == DateTime.now().month && 
                      currentDay.year == DateTime.now().year;
      
      dayWidgets.add(
        GestureDetector(
          onTap: () => _onDaySelected(currentDay),
          child: Container(
            margin: EdgeInsets.all(2.h),
            decoration: BoxDecoration(
              color: isToday ? Colors.blue[800] : Colors.transparent, // Используем стандартный цвет
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                color: isToday ? appTheme.whiteA700 : Colors.blue[800], // Используем стандартный цвет
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                fontSize: 12.fSize,
              ),
            ),
          ),
        ),
      );
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(vertical: 12.v),
          child: Text(
            _getMonthName(currentMonth.month) + ' ${currentMonth.year}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16.fSize,
              color: Colors.blue[800], // Используем стандартный цвет
            ),
          ),
        ),
        
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 7,
          childAspectRatio: 1.0,
          mainAxisSpacing: 2.h,
          crossAxisSpacing: 2.h,
          children: dayWidgets,
        ),
        
        SizedBox(height: 16.v),
        
        Container(
          padding: EdgeInsets.all(8.h),
          decoration: BoxDecoration(
            color: Colors.grey[200], // Используем стандартный цвет
            borderRadius: BorderRadius.circular(8.h),
          ),
          child: Text(
            'Нажмите на дату, чтобы добавить мероприятие',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.fSize,
              color: Colors.blue[800], // Используем стандартный цвет
            ),
          ),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    final months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    return months[month - 1];
  }

  void _onDaySelected(DateTime selectedDay) {
    print('Выбран день: $selectedDay');
    Get.snackbar(
      'Календарь',
      'Выбрана дата: ${selectedDay.day}.${selectedDay.month}.${selectedDay.year}',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.blue[800], // Используем стандартный цвет
      colorText: appTheme.whiteA700,
    );
  }

  void _showSuccessMessage() {
    Get.snackbar(
      'Успешно',
      'Мероприятие добавлено в календарь',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: Duration(seconds: 2),
    );
  }
}