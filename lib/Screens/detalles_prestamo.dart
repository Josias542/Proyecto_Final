import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'prestamos.dart';
import 'pagos.dart';
import 'dart:math';

class DetallesPrestamo extends StatelessWidget {
  final String clienteId;

  DetallesPrestamo({required this.clienteId});

  // Función para calcular la tabla de amortización inicial
  List<Map<String, dynamic>> calcularAmortizacionInicial(double monto, double tasaInteres, int plazo) {
    List<Map<String, dynamic>> tablaAmortizacion = [];
    double tasaMensual = tasaInteres / 100 / 12;

    double pagoMensual = (monto * tasaMensual) / (1 - (1 / pow(1 + tasaMensual, plazo)));

    double saldoRestante = monto;

    for (int i = 1; i <= plazo; i++) {
      double interes = saldoRestante * tasaMensual;
      double principal = pagoMensual - interes;

      if (principal > saldoRestante) {
        principal = saldoRestante;
        interes = pagoMensual - principal;
      }

      saldoRestante -= principal;

      tablaAmortizacion.add({
        'cuota': i,
        'pago': pagoMensual,
        'interes': interes,
        'principal': principal,
        'saldoRestante': saldoRestante,
        'estado': 'Pendiente',
      });
    }

    return tablaAmortizacion;
  }

  Future<void> _eliminarPrestamo(String prestamoId, BuildContext context) async {
    await FirebaseFirestore.instance.collection('prestamos').doc(prestamoId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Préstamo eliminado correctamente.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Detalles del Préstamo', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent, Colors.lightBlueAccent],
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('prestamos')
              .where('clienteId', isEqualTo: clienteId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: Colors.white));
            return ListView.builder(
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var prestamo = snapshot.data!.docs[index];
                double monto = prestamo['monto'];
                double tasaInteres = prestamo['tasaInteres'];
                int plazo = prestamo['plazo'];

                var tablaAmortizacion = calcularAmortizacionInicial(monto, tasaInteres, plazo);

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('pagos')
                      .where('prestamoId', isEqualTo: prestamo.id)
                      .snapshots(),
                  builder: (context, pagosSnapshot) {
                    if (!pagosSnapshot.hasData) return CircularProgressIndicator();

                    List<Map<String, dynamic>> pagos = pagosSnapshot.data!.docs.map((pago) {
                      return {
                        'monto': pago['monto'],
                        'fechaPago': pago['fechaPago'],
                        'cuota': pago['cuota'],
                      };
                    }).toList();

                    // Ordenar el historial de pagos por número de cuota
                    pagos.sort((a, b) => a['cuota'].compareTo(b['cuota']));

                    for (var pago in pagos) {
                      int cuota = pago['cuota'];
                      double montoPagado = pago['monto'];

                      for (var entry in tablaAmortizacion) {
                        if (entry['cuota'] == cuota) {
                          entry['estado'] = montoPagado >= entry['pago'] ? 'Pagada' : 'Parcial';
                        }
                      }
                    }

                    // Verificar si todas las cuotas están pagadas
                    bool todasLasCuotasPagadas = tablaAmortizacion.every((entry) => entry['estado'] == 'Pagada');

                    // Si todas las cuotas están pagadas, marcar el préstamo como "Pagado"
                    if (todasLasCuotasPagadas) {
                      FirebaseFirestore.instance.collection('prestamos').doc(prestamo.id).update({
                        'estado': 'Pagado',
                      });
                    }

                    return Card(
                      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 4,
                      child: ExpansionTile(
                        title: Text('Préstamo \$${prestamo['monto'].toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Tasa: ${prestamo['tasaInteres']}% - Cuotas: ${prestamo['plazo']}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              children: [
                                if (todasLasCuotasPagadas)
                                  Text(
                                    '¡Préstamo Pagado!',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                                  ),
                                Text('Tabla de Amortización', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ...tablaAmortizacion.map((entry) {
                                  Color colorEstado = entry['estado'] == 'Pagada' ? Colors.green : (entry['estado'] == 'Parcial' ? Colors.orange : Colors.red);
                                  return ListTile(
                                    title: Text('Cuota ${entry['cuota']} - ${entry['estado']}'),
                                    subtitle: Text(
                                      'Pago: \$${entry['pago'].toStringAsFixed(2)}\n'
                                      'Interés: \$${entry['interes'].toStringAsFixed(2)}\n'
                                      'Principal: \$${entry['principal'].toStringAsFixed(2)}\n'
                                      'Saldo: \$${entry['saldoRestante'].toStringAsFixed(2)}',
                                    ),
                                    trailing: Icon(Icons.circle, color: colorEstado),
                                  );
                                }).toList(),
                                Divider(),
                                Text('Historial de Pagos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ...pagos.map((pago) {
                                  return ListTile(
                                    title: Text('Pago: \$${pago['monto'].toStringAsFixed(2)} (Cuota ${pago['cuota']})'),
                                    subtitle: Text('Fecha: ${pago['fechaPago'].toDate().toString()}'),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                          if (!todasLasCuotasPagadas)
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AgregarPago(prestamoId: prestamo.id),
                                  ),
                                );
                              },
                              child: Text('Agregar Pago', style: TextStyle(color: Colors.blueAccent)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                              ),
                            ),
                          ElevatedButton(
                            onPressed: () => _eliminarPrestamo(prestamo.id, context),
                            child: Text('Eliminar Préstamo', style: TextStyle(color: Colors.red)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AgregarPrestamo(clienteId: clienteId),
            ),
          );
        },
        child: Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }
}