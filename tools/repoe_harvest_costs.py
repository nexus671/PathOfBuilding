import json
from pathlib import Path
from RePoE.parser import Parser_Module

class harvest_costs(Parser_Module):
    def write(self):
        result=[]
        for row in self.relational_reader['HarvestCraftOptions.dat64']:
            result.append({k:row[k] for k in ['Id','Text','Command','Parameters','IsEnchant','LifeforceTypes','LifeforceCosts','IsProportionalToStackSize']})
        Path(self.data_path,'harvest_costs.json').write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
