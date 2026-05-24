#!/usr/bin/env python3
"""Genera tabla de resultados QA desde test_results.json"""
import json, os

results_file = os.path.join(os.path.dirname(__file__), 'results', 'test_results.json')
with open(results_file, 'r', encoding='utf-8') as f:
    data = json.load(f)

# Sort by prueba number
data.sort(key=lambda x: int(x['prueba']))

print(f"Total de pruebas: {len(data)}")
cumple = sum(1 for r in data if r['resultado'] == 'CUMPLE')
no_cumple = sum(1 for r in data if r['resultado'] == 'NO CUMPLE')
print(f"CUMPLE: {cumple} | NO CUMPLE: {no_cumple}\n")

print("| N° | Tipo | Descripción | Resultado | Observaciones |")
print("|---|---|---|---|---|")
for r in data:
    desc = r['descripcion'].replace('|', '/')
    obs = r['desviacion'].replace('|', '/').replace('\n', ' ')[:120]
    if len(r['desviacion']) > 120:
        obs += '...'
    result_icon = "✅ CUMPLE" if r['resultado'] == 'CUMPLE' else "❌ NO CUMPLE"
    print(f"| {r['prueba']:2} | {r['tipo']} | {desc} | {result_icon} | {obs} |")
