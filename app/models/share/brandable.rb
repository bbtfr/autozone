module Share
  module Brandable
    extend ActiveSupport::Concern

    Brands = ["阿斯顿·马丁", "奥迪", "巴博斯", "宝骏", 
      "宝马", "保时捷", "北京汽车", "北汽威旺", "北汽制造", 
      "奔驰", "奔腾", "本田", "比亚迪", "标致", "别克", 
      "宾利", "布加迪", "昌河", "长安", "长安商用", "长城", 
      "DS", "大众", "道奇", "东风", "东风风度", "东风风神", 
      "东风小康", "东南", "法拉利", "菲亚特", "丰田", "风行", 
      "福迪", "福特", "福田", "GMC", "光冈", "广汽传祺", 
      "广汽吉奥", "哈飞", "哈弗", "海格", "海马", "悍马", 
      "恒天", "红旗", "华泰", "黄海", "Jeep", "吉利帝豪", 
      "吉利全球鹰", "吉利英伦", "江淮", "江铃", "捷豹", "金杯", 
      "金旅", "九龙", "卡尔森", "开瑞", "凯迪拉克", "科尼赛克", 
      "克莱斯勒", "兰博基尼", "劳伦士", "劳斯莱斯", "雷克萨斯", 
      "雷诺", "理念", "力帆", "莲花汽车", "猎豹汽车", "林肯", 
      "铃木", "陆风", "路虎", "路特斯", "MG", "MINI", 
      "马自达", "玛莎拉蒂", "迈凯伦", "摩根", "纳智捷", "讴歌", 
      "欧宝", "欧朗", "奇瑞", "启辰", "起亚", "日产", "荣威", 
      "如虎", "瑞麒", "SMART", "三菱", "陕汽通家", "上汽大通", 
      "绅宝", "世爵", "双环", "双龙", "思铭", "斯巴鲁", 
      "斯柯达", "威麟", "威兹曼", "沃尔沃", "五菱汽车", 
      "五十铃", "西雅特", "现代", "新凯", "雪佛兰", "雪铁龙", 
      "野马汽车", "一汽", "依维柯", "英菲尼迪", "永源", "中华", 
      "中兴", "众泰", "其它", 
    ]

    included do
      extend Share::Id2Key
      define_id2key_methods :brand
    end

    def self.get_id brand
      if brand.kind_of? Integer then brand else Brands.index brand end
    end

  end
end