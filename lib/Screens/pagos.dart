import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class AgregarPago extends StatefulWidget {
  final String prestamoId;

  AgregarPago({required this.prestamoId});

  @override
  _AgregarPagoState createState() => _AgregarPagoState();
}

class _AgregarPagoState extends State<AgregarPago> {
  final _formularioKey = GlobalKey<FormState>();
  int? _cuotaSeleccionada;
  List<Map<String, dynamic>> _cuotas = [];
  double _pagoMensual = 0.0;

  @override
  void initState() {
    super.initState();
    _cargarCuotas();
    _calcularPagoMensual();
  }

  Future<void> _cargarCuotas() async {
    var cuotasSnapshot = await FirebaseFirestore.instance
        .collection('prestamos')
        .doc(widget.prestamoId)
        .collection('cuotas')
        .where('estado', isEqualTo: 'Pendiente')
        .get();

    // Ordenar las cuotas manualmente por número
    var cuotas = cuotasSnapshot.docs.map((doc) {
      return {
        'id': doc.id,
        'numero': doc['numero'],
      };
    }).toList();

    cuotas.sort((a, b) => a['numero'].compareTo(b['numero']));

    setState(() {
      _cuotas = cuotas;
    });
  }

  Future<void> _calcularPagoMensual() async {
    var prestamoDoc = await FirebaseFirestore.instance.collection('prestamos').doc(widget.prestamoId).get();
    var prestamo = prestamoDoc.data() as Map<String, dynamic>;

    double monto = prestamo['monto'];
    double tasaInteres = prestamo['tasaInteres'];
    int plazo = prestamo['plazo'];

    double tasaMensual = tasaInteres / 100 / 12;
    _pagoMensual = (monto * tasaMensual) / (1 - (1 / pow(1 + tasaMensual, plazo)));

    setState(() {});
  }

  Future<void> _registrarPago(int cuota) async {
    // Registrar el pago
    await FirebaseFirestore.instance.collection('pagos').add({
      'prestamoId': widget.prestamoId,
      'monto': _pagoMensual,
      'fechaPago': DateTime.now(),
      'cuota': cuota,
    });

    // Marcar la cuota como pagada
    await FirebaseFirestore.instance
        .collection('prestamos')
        .doc(widget.prestamoId)
        .collection('cuotas')
        .doc(_cuotas.firstWhere((c) => c['numero'] == cuota)['id'])
        .update({
      'estado': 'Pagada',
    });

    // Actualizar el saldo del préstamo
    var prestamoDoc = await FirebaseFirestore.instance.collection('prestamos').doc(widget.prestamoId).get();
    var prestamo = prestamoDoc.data() as Map<String, dynamic>;

    double saldoActual = prestamo['saldo'] ?? prestamo['monto'];
    saldoActual -= _pagoMensual;

    await FirebaseFirestore.instance.collection('prestamos').doc(widget.prestamoId).update({
      'saldo': saldoActual,
    });

    // Si el saldo es cero, marcar el préstamo como pagado
    if (saldoActual <= 0) {
      await FirebaseFirestore.instance.collection('prestamos').doc(widget.prestamoId).update({
        'estado': 'Pagado',
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Pago registrado correctamente.')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agregar Pago', style: TextStyle(color: Colors.white)),
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
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formularioKey,
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  value: _cuotaSeleccionada,
                  decoration: InputDecoration(
                    labelText: 'Cuota',
                    labelStyle: TextStyle(color: Colors.white),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
                  ),
                  items: _cuotas.map((cuota) {
                    return DropdownMenuItem<int>(
                      value: cuota['numero'],
                      child: Text(
                        'Cuota ${cuota['numero']}',
                        style: TextStyle(color: Colors.black),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _cuotaSeleccionada = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Por favor seleccione una cuota';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),
                Text(
                  'Monto a pagar: \$${_pagoMensual.toStringAsFixed(2)}',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_formularioKey.currentState!.validate()) {
                      await _registrarPago(_cuotaSeleccionada!);
                    }
                  },
                  child: Text('Pagar Cuota', style: TextStyle(color: Colors.blueAccent)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}