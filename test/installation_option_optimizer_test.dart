import 'package:elecx/src/domain/cable_spec.dart';
import 'package:elecx/src/domain/installation_path.dart';
import 'package:elecx/src/domain/route_host.dart';
import 'package:elecx/src/domain/route_medium.dart';
import 'package:elecx/src/engine/installation_option_optimizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'optimizer rejects infeasible cheap path before ranking feasible options',
    () {
      final cable = CableSpec(
        id: 'power-5x6',
        name: 'Power 5x6',
        medium: RouteMediumProfile.acPower,
        outerDiameterMm: 16,
        segregationClass: CableSegregationClass.power,
        conductorMaterial: ConductorMaterial.copper,
        conductorCount: 5,
        conductorCrossSectionMm2: 6,
      );

      final smallConduit = InstallationPathSpec(
        id: 'small-conduit',
        name: 'Small conduit',
        method: InstallationMethod.conduit,
        materialCostPerMeter: 1,
        laborCostPerMeter: 1,
        channels: [
          InstallationChannelSpec(
            id: 'a',
            capacityModel: ChannelCapacityModel.areaFill,
            usableAreaMm2: 300,
            maxFillRatio: 0.40,
            reserveRatio: 0.20,
            allowedSegregationClasses: const {CableSegregationClass.power},
          ),
        ],
      );
      final trench = InstallationPathSpec(
        id: 'trench',
        name: 'Underground trench',
        method: InstallationMethod.undergroundTrench,
        materialCostPerMeter: 8,
        laborCostPerMeter: 12,
        channels: [
          InstallationChannelSpec(
            id: 'power',
            capacityModel: ChannelCapacityModel.cableCount,
            maxCableCount: 6,
            allowedSegregationClasses: const {CableSegregationClass.power},
          ),
        ],
      );
      final facade = InstallationPathSpec(
        id: 'facade',
        name: 'Facade tray',
        method: InstallationMethod.facade,
        materialCostPerMeter: 4,
        laborCostPerMeter: 5,
        channels: [
          InstallationChannelSpec(
            id: 'power',
            capacityModel: ChannelCapacityModel.cableCount,
            maxCableCount: 6,
            allowedSegregationClasses: const {CableSegregationClass.power},
          ),
        ],
      );

      final result = InstallationOptionOptimizer.evaluate(
        routeId: 'gate-feed',
        cable: cable,
        quantity: 2,
        candidates: [
          InstallationOptionCandidate(
            id: 'cheap-but-small',
            pathSpec: smallConduit,
            host: RouteHostRef.outdoor('yard'),
            lengthMm: 10000,
            channelId: 'a',
          ),
          InstallationOptionCandidate(
            id: 'trench-option',
            pathSpec: trench,
            host: RouteHostRef.outdoor('yard'),
            lengthMm: 9000,
            channelId: 'power',
          ),
          InstallationOptionCandidate(
            id: 'facade-option',
            pathSpec: facade,
            host: RouteHostRef.outdoor('yard'),
            lengthMm: 11000,
            channelId: 'power',
          ),
        ],
      );

      final cheap = result.assessments.first;
      expect(cheap.feasible, isFalse);
      expect(result.recommended?.candidate.id, 'facade-option');
      expect(result.recommended?.totalInstallationCost, closeTo(99, 0.001));
    },
  );
}
